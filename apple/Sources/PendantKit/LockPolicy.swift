import Foundation

/// When the optional app lock asks again.
public enum LockPolicy {
    /// How long the app can be away before it asks again, so a quick glance at another app is not a chore.
    public static let grace: TimeInterval = 30

    public static func needsUnlock(enabled: Bool, leftAt: Date?, now: Date, grace: TimeInterval = LockPolicy.grace) -> Bool {
        guard enabled else { return false }
        guard let leftAt else { return true } // never recorded leaving: be safe
        return now.timeIntervalSince(leftAt) >= grace
    }
}
