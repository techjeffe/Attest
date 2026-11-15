import AppIntents

/// Settings > Action Button > Shortcut > "Record in Attest" (also in Shortcuts and Siri). The app opens and the
/// page starts recording, or stops it if one is running. It cannot start silently from a locked phone: iOS only
/// gives the microphone to a foreground app.
struct ToggleRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Record in Attest"
    static var description = IntentDescription("Starts a recording in Attest, or stops the one that is running.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        RecordingCommands.shared.request(.toggle)
        return .result()
    }
}

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start recording in Attest"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        RecordingCommands.shared.request(.start)
        return .result()
    }
}

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop recording in Attest"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        RecordingCommands.shared.request(.stop)
        return .result()
    }
}

struct AttestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ToggleRecordingIntent(), phrases: ["Record in \(.applicationName)", "Start \(.applicationName)"],
                    shortTitle: "Record", systemImageName: "mic.circle.fill")
        AppShortcut(intent: StopRecordingIntent(), phrases: ["Stop recording in \(.applicationName)"],
                    shortTitle: "Stop recording", systemImageName: "stop.circle.fill")
    }
}
