import Foundation

struct CellAddress: Equatable, Sendable {
    let row: Int
    let column: Int
}

struct CellSelection: Equatable, Sendable {
    let rows: [[String]]
    let lastCell: CellAddress
}

enum WriteTarget: String, CaseIterable, Identifiable, Sendable {
    case nextColumn
    case nextRow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nextColumn:
            return "Next Column"
        case .nextRow:
            return "Next Row"
        }
    }
}

enum ModelState: Equatable {
    case idle
    case loading
    case ready
    case failed

    var statusText: String {
        switch self {
        case .idle:
            return "Model idle"
        case .loading:
            return "Loading model"
        case .ready:
            return "Model ready"
        case .failed:
            return "Model failed"
        }
    }
}
