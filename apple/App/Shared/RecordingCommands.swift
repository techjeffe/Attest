import Foundation

/// What the Action Button (or a Shortcut, or Siri) asked the page to do with the microphone.
enum RecordingCommand: String { case start, stop, toggle }

/// A hand-off from App Intents to the web view. iOS only lets an app capture the microphone from the
/// foreground, so the intent opens Attest and parks the command here; RootView delivers it once the page has loaded.
@MainActor
final class RecordingCommands: ObservableObject {
    static let shared = RecordingCommands()
    @Published var pending: RecordingCommand?
    /// Whether the page says a recording is running (the `recording` message from recorder.js).
    @Published var isRecording = false
    func request(_ c: RecordingCommand) { pending = c }
}
