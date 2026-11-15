import SwiftUI
import PendantKit

struct RootView: View {
    @ObservedObject private var pendant = PendantModel.shared
    @State private var showPendant = false
    @State private var showSetup = false
    @State private var incoming: IncomingLink?

    var body: some View {
        Group {
            if let url = pendant.serverURL {
                ZStack(alignment: .bottomTrailing) {
                    // Behind the page, so the status-bar strip is the app's own dark, not white.
                    Color(red: 9 / 255, green: 9 / 255, blue: 11 / 255).ignoresSafeArea()
                    WebView(url: url, onOpenPendant: { showPendant = true }).ignoresSafeArea(edges: .bottom)
                    // Only when there is something to say (recordings waiting, syncing, a problem), clear of the
                    // header and the tab bar. Otherwise the pendant lives in Settings > Open pendant sync.
                    if pendant.needsAttention {
                        PendantChip(pendant: pendant) { showPendant = true }
                            .padding(.trailing, 12).padding(.bottom, 74)
                    }
                }
                .preferredColorScheme(.dark)
                .sheet(isPresented: $showPendant) { PendantSheet(pendant: pendant, edit: { showPendant = false; showSetup = true }) }
            } else {
                SetupView(pendant: pendant)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSetup) { SetupView(pendant: pendant) { showSetup = false }.preferredColorScheme(.dark) }
        .task { pendant.refreshQueue() }
        // attest://connect?... from setup. Anyone can send you a link, so the address is confirmed first.
        .onOpenURL { url in incoming = ConnectLink.parse(url).map(IncomingLink.init) }
        .sheet(item: $incoming) { link in
            ConnectConfirm(config: link.config,
                           connect: { pendant.apply(link.config); incoming = nil },
                           cancel: { incoming = nil })
                .preferredColorScheme(.dark)
        }
    }
}

struct IncomingLink: Identifiable { let id = UUID(); let config: ServerConfig }

/// A small status pill over the web app: tap for the pendant panel.
struct PendantChip: View {
    @ObservedObject var pendant: PendantModel
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.badge.mic")
                if pendant.queued > 0 { Text("\(pendant.queued)").font(.caption.bold()) }
                if case .draining(let a, let b) = pendant.phase { Text("\(a)/\(b)").font(.caption.monospacedDigit()) }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pendant")
    }
}

struct PendantSheet: View {
    @ObservedObject var pendant: PendantModel
    var edit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Limitless pendant").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
            }
            Text(pendant.message).foregroundStyle(pendant.phase == .failed ? .red : .secondary)
            if case .draining(let a, let b) = pendant.phase { ProgressView(value: Double(a), total: Double(max(b, 1))) }
            LabeledContent("Waiting to upload", value: "\(pendant.queued)")
            if let d = pendant.lastSync { LabeledContent("Last sync", value: d.formatted(date: .abbreviated, time: .shortened)) }
            if !pendant.hasToken {
                Label("Add the Client ID and secret that setup printed, or the server will refuse uploads.", systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Button {
                Task { await pendant.sync() }
            } label: {
                Label(pendant.phase == .connecting || pendant.phase == .uploading || { if case .draining = pendant.phase { return true } else { return false } }() ? "Syncing…" : "Sync now",
                      systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Text("A pendant talks to one phone at a time. If it is connected to another app, such as Omi, turn Bluetooth off there first.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Server and sign-in…", action: edit).font(.footnote)
            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium])
    }
}

struct SetupView: View {
    @ObservedObject var pendant: PendantModel
    var done: (() -> Void)?
    @State private var checking = false
    @State private var problem: String?
    @State private var showHelp = false
    @FocusState private var focus: Field?
    private enum Field { case server, id, secret }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill").font(.system(size: 52)).foregroundStyle(.tint)
                    Text("Connect to your Attest").font(.title2.bold())
                    Text("Attest runs on your own Mac or Cloudflare account. Enter its address to open it here.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
            Section {
                TextField("attest.example.com", text: $pendant.server)
                    .autocorrectionDisabled().focused($focus, equals: .server)
                    .submitLabel(.go).onSubmit { Task { await connect() } }
                    #if os(iOS)
                    .textInputAutocapitalization(.never).keyboardType(.URL).textContentType(.URL)
                    #endif
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), let c = ConnectLink.parse(url) {
                        pendant.server = c.server.absoluteString; pendant.clientId = c.clientId; pendant.clientSecret = c.clientSecret
                    } else { pendant.server = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    problem = nil
                }
                .labelStyle(.titleAndIcon)
            } header: { Text("Server") } footer: {
                if let problem { Label(problem, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                else { Button("How do I get this?") { showHelp = true }.font(.footnote) }
            }
            Section {
                DisclosureGroup("Pendant sign-in (optional)") {
                    TextField("Client ID", text: $pendant.clientId).autocorrectionDisabled().focused($focus, equals: .id)
                        .submitLabel(.next).onSubmit { focus = .secret }
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    SecureField("Client secret", text: $pendant.clientSecret).focused($focus, equals: .secret)
                        .submitLabel(.go).onSubmit { Task { await connect() } }
                    Text("Only for syncing a Bluetooth pendant. Leave empty if you only use Attest in the app.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button { Task { await connect() } } label: {
                    HStack { if checking { ProgressView() }; Text(checking ? "Checking…" : "Connect").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(checking || pendant.server.trimmingCharacters(in: .whitespaces).isEmpty)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 9 / 255, green: 9 / 255, blue: 11 / 255).ignoresSafeArea())
        .frame(maxWidth: 520)
        .sheet(isPresented: $showHelp) { SetupHelp() }
        .onAppear { if pendant.server.isEmpty { focus = .server } }
    }

    private func connect() async {
        problem = nil
        pendant.server = ServerProbe.normalize(pendant.server)
        guard let url = pendant.serverURL, url.host != nil else {
            problem = "That is not a web address."; Haptics.play("error"); return
        }
        checking = true; defer { checking = false }
        switch await ServerProbe.check(url) {
        case .ok, .needsSignIn:
            Haptics.play("success")
            pendant.save(); done?()
        case .notAttest:
            problem = "That address answered, but it does not look like an Attest."; Haptics.play("error")
        case .unreachable:
            problem = "Could not reach \(url.host ?? "that address"). Check the address and that the server is running."; Haptics.play("error")
        }
    }
}

struct SetupHelp: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Attest is not a hosted service: you run it yourself, so your recordings stay yours.")
                    Text("On a computer, run `npm run setup` in the Attest folder (the README walks through it). It prints your address and a link. Tap the link on this phone, or paste it here, and everything fills in.")
                    Text("The pendant sign-in (Client ID and secret) is only needed to sync a Bluetooth pendant.").foregroundStyle(.secondary)
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Setting up")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

/// The single confirmation for an attest://connect link. Anyone can send you a link, so the address is shown first.
struct ConnectConfirm: View {
    let config: ServerConfig
    var connect: () -> Void
    var cancel: () -> Void
    private var secure: Bool { config.server.scheme == "https" }
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: secure ? "lock.fill" : "lock.open.fill").font(.largeTitle).foregroundStyle(secure ? .green : .orange)
            Text("Connect to \(config.server.host ?? "")?").font(.title3.bold()).multilineTextAlignment(.center)
            Text(secure ? "Attest will sign in to this server and upload your pendant recordings to it. Only continue if this is your own Attest."
                        : "This address is not encrypted (http). That is fine for a development server on this Mac, but do not use it for anything else.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Connect", action: connect).buttonStyle(.borderedProminent).controlSize(.large)
            Button("Cancel", role: .cancel, action: cancel)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
