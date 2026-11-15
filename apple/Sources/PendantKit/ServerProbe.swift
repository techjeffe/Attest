import Foundation

/// Checks that an address is an Attest before the app commits to it, so a typo or a server that is down is
/// caught on the Connect screen instead of surfacing as a blank web view.
public enum ServerProbe {
    public enum Result: Equatable {
        /// Reached the Attest page.
        case ok
        /// Reached something that wants a sign-in first (Cloudflare Access). Expected for a deployed Attest:
        /// the sign-in happens inside the app, so this is a pass.
        case needsSignIn
        /// Reached a server, but not an Attest.
        case notAttest
        /// No answer: wrong address, offline, or the server is down.
        case unreachable(String)
    }

    /// "attest.example.com" -> "https://attest.example.com". Plain localhost addresses stay http.
    public static func normalize(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains("://") else { return s }
        let host = s.split(separator: "/").first.map(String.init) ?? s
        let local = host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1")
        return (local ? "http://" : "https://") + s
    }

    /// Pure: what an HTTP answer means. `finalHost` is where redirects ended up.
    public static func classify(status: Int, finalHost: String?, expectedHost: String?, body: String) -> Result {
        if let f = finalHost, let e = expectedHost, f != e { return .needsSignIn } // bounced to an identity provider
        if status == 401 || status == 403 { return .needsSignIn }
        if (200..<300).contains(status), body.range(of: "attest", options: .caseInsensitive) != nil { return .ok }
        return .notAttest
    }

    public static func check(_ url: URL, session: URLSession = .shared) async -> Result {
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("text/html", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .notAttest }
            let body = String(decoding: data.prefix(4096), as: UTF8.self)
            return classify(status: http.statusCode, finalHost: http.url?.host, expectedHost: url.host, body: body)
        } catch {
            return .unreachable((error as? URLError)?.localizedDescription ?? error.localizedDescription)
        }
    }
}
