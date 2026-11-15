import SwiftUI
import LocalAuthentication
import PendantKit

/// An optional lock for the app: Face ID, Touch ID or the device passcode before anything is shown. Attest holds
/// private recordings, so this is off by default but one switch away (Settings > Require Face ID). The pendant's
/// background sync is unaffected: it never shows the web view, and the Keychain secret stays readable after first unlock.
@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()
    private static let key = "lockEnabled"
    @Published var enabled: Bool = UserDefaults.standard.bool(forKey: AppLock.key) {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.key); if !enabled { locked = false } }
    }
    /// True from launch until you authenticate, when the lock is on.
    @Published var locked: Bool = UserDefaults.standard.bool(forKey: AppLock.key)
    @Published var failed = false
    private var leftAt: Date?
    private var authenticating = false

    func didLeave() { if leftAt == nil { leftAt = Date() } }
    func didReturn() {
        if LockPolicy.needsUnlock(enabled: enabled, leftAt: leftAt, now: Date()) { locked = true }
        leftAt = nil
    }

    var canAuthenticate: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    /// Turning it on proves it works first: otherwise a phone with no passcode would lock you out.
    func setEnabled(_ on: Bool) async -> Bool {
        if !on { enabled = false; return true }
        guard canAuthenticate else { return false }
        guard await evaluate("Turn on the Attest lock") else { return false }
        enabled = true; locked = false
        return true
    }

    func unlock() async {
        guard locked, !authenticating else { return }
        authenticating = true; failed = false
        let ok = await evaluate("Unlock Attest")
        authenticating = false
        if ok { locked = false } else { failed = true }
    }

    private func evaluate(_ reason: String) async -> Bool {
        let ctx = LAContext()
        return (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Covers everything while locked, and while the app is not active (so the app switcher shows no recordings).
struct LockCover: View {
    @ObservedObject var lock: AppLock
    var body: some View {
        ZStack {
            Color(red: 9 / 255, green: 9 / 255, blue: 11 / 255).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.secondary)
                Text("Attest is locked").font(.title3.bold())
                if lock.locked {
                    Button { Task { await lock.unlock() } } label: { Label("Unlock", systemImage: "faceid").frame(maxWidth: 200) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    if lock.failed { Text("Could not unlock. Try again.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
        }
        .transition(.opacity)
    }
}
