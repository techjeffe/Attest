import SwiftUI
import WebKit

#if os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
#else
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

/// Where the page is in loading, so the app can show a splash first and a real error (with Retry) instead of
/// a blank screen when the server is down or the phone is offline.
@MainActor
final class WebLoader: ObservableObject {
    enum State: Equatable { case loading, ready, failed(String) }
    @Published var state: State = .loading
    /// True once the page has loaded at least once: the splash is only for the first load.
    @Published var hasLoaded = false
    fileprivate weak var webView: WKWebView?

    func reload() {
        state = .loading
        if webView?.url == nil { webView?.load(URLRequest(url: reloadURL)) } else { webView?.reload() }
    }
    var reloadURL: URL = URL(string: "about:blank")!
}

/// Attest itself: the same web app, with its phone layout and bottom tab bar. Sign-in (Cloudflare Access)
/// happens inside it and the session persists.
struct WebView: PlatformViewRepresentable {
    let url: URL
    @ObservedObject var loader: WebLoader
    /// The page can ask the app to open its native pendant panel (Settings > Open pendant sync).
    var onOpenPendant: () -> Void = {}
    /// Settings > Change server asks the app to show the Connect screen.
    var onChangeServer: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(loader, onOpenPendant, onChangeServer) }

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        let onOpenPendant: () -> Void
        let onChangeServer: () -> Void
        let loader: WebLoader
        init(_ l: WebLoader, _ f: @escaping () -> Void, _ g: @escaping () -> Void) { loader = l; onOpenPendant = f; onChangeServer = g }

        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            let body = m.body as? [String: Any]
            switch body?["action"] as? String {
            case "pendant": DispatchQueue.main.async { self.onOpenPendant() }
            case "server": DispatchQueue.main.async { self.onChangeServer() }
            case "haptic": Haptics.play(body?["style"] as? String)
            default: break
            }
        }

        // MARK: load state
        func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { Task { @MainActor in loader.state = .loading } }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
            Task { @MainActor in loader.state = .ready; loader.hasLoaded = true }
            endRefreshing(w)
        }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { fail(w, e) }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { fail(w, e) }
        private func fail(_ w: WKWebView, _ e: Error) {
            endRefreshing(w)
            let ns = e as NSError
            // A navigation replaced by another (a redirect, a tap while loading) is not a failure.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            Task { @MainActor in loader.state = .failed(WebLoader.describe(ns)) }
        }
        private func endRefreshing(_ w: WKWebView) {
            #if os(iOS)
            DispatchQueue.main.async { w.scrollView.refreshControl?.endRefreshing() }
            #endif
        }

        #if os(iOS)
        /// Pull-to-refresh: ask the page to refresh its own screen, falling back to a full reload when it is not running.
        @objc func pulled(_ r: UIRefreshControl) {
            guard let w = loader.webView else { r.endRefreshing(); return }
            Task { @MainActor in
                Haptics.play("light")
                let handled = try? await w.callAsyncJavaScript(
                    "if (typeof window.attestRefresh === 'function') { await window.attestRefresh(); return true } return false",
                    contentWorld: .page) as? Bool
                if handled == true { r.endRefreshing() } else { w.reload() }
            }
        }
        // <input type=file> and microphone prompts work through the system sheets.
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.prompt) }
        #endif
    }

    private func make(_ c: Coordinator) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        #if os(iOS)
        cfg.allowsInlineMediaPlayback = true
        #endif
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.userContentController.add(c, name: "attest")
        let v = WKWebView(frame: .zero, configuration: cfg)
        #if os(iOS)
        v.isOpaque = false
        v.backgroundColor = .clear
        let rc = UIRefreshControl()
        rc.addTarget(c, action: #selector(Coordinator.pulled(_:)), for: .valueChanged)
        v.scrollView.refreshControl = rc
        #endif
        v.uiDelegate = c
        v.navigationDelegate = c
        v.allowsBackForwardNavigationGestures = true
        loader.webView = v
        loader.reloadURL = url
        v.load(URLRequest(url: url))
        return v
    }
    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { make(context.coordinator) }
    func updateUIView(_ v: WKWebView, context: Context) {}
    #else
    func makeNSView(context: Context) -> WKWebView { make(context.coordinator) }
    func updateNSView(_ v: WKWebView, context: Context) {}
    #endif
}

extension WebLoader {
    /// A sentence for the error view.
    nonisolated static func describe(_ e: NSError) -> String {
        guard e.domain == NSURLErrorDomain else { return e.localizedDescription }
        switch e.code {
        case NSURLErrorNotConnectedToInternet: return "You appear to be offline."
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
            return "The server did not answer. Check that it is running and the address is right."
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted: return "A secure connection could not be made."
        default: return e.localizedDescription
        }
    }
}

/// Native haptics for the web UI: WKWebView ignores navigator.vibrate, so the page asks for them over the
/// `attest` message handler. Unknown styles do nothing. A no-op on the Mac.
enum Haptics {
    static func play(_ style: String?) {
        #if os(iOS)
        DispatchQueue.main.async {
            switch style {
            case "light": UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case "heavy": UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case "selection": UISelectionFeedbackGenerator().selectionChanged()
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "warning": UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
            default: break
            }
        }
        #endif
    }
}
