import Foundation

enum NumbersError: LocalizedError {
    case appleEventsPermissionDenied
    case scriptFailed(String)
    case invalidSelection
    case invalidScriptResult

    var errorDescription: String? {
        switch self {
        case .appleEventsPermissionDenied:
            return "Automation permission was denied. Allow Numbers Wingman to control Numbers in System Settings > Privacy & Security > Automation."
        case .scriptFailed(let message):
            return "Numbers automation failed: \(message)"
        case .invalidSelection:
            return "Select one or more cells in the front Numbers document, then try again."
        case .invalidScriptResult:
            return "Numbers returned a result that could not be parsed."
        }
    }
}
