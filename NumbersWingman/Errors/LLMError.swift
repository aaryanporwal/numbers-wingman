import Foundation

enum LLMError: LocalizedError {
    case modelNotLoaded
    case mlxUnavailable
    case emptyResponse
    case invalidModelRepository(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The model has not finished loading."
        case .mlxUnavailable:
            return "MLX inference is not wired yet in this scaffold."
        case .emptyResponse:
            return "The model finished without a visible answer. Try a more direct instruction."
        case .invalidModelRepository(let id):
            return "Invalid Hugging Face model repository: \(id)"
        }
    }
}
