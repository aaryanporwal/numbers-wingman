import Foundation
import Observation

@Observable
@MainActor
final class MenuBarViewModel {
    var modelState: ModelState = .idle
    var modelProgress = 0.0
    var cellRows: [[String]] = []
    var prompt = ""
    var outputText = ""
    var errorMessage: String?
    var generationStatus: String?
    var isReading = false
    var isGenerating = false
    var isWriting = false
    var didFinishGeneration = false
    var writeTarget: WriteTarget = .nextColumn

    private let numbersBridge = NumbersBridge()
    private let llmManager = LLMManager()
    private var selectedCells: CellSelection?

    var cellContext: String {
        cellRows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    var isBusy: Bool {
        isReading || isGenerating || isWriting
    }

    var canGenerate: Bool {
        modelState != .loading && !isGenerating && !cellContext.isEmpty && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canWrite: Bool {
        !isWriting && didFinishGeneration && !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCells != nil
    }

    func loadModel() async {
        guard modelState == .idle else { return }
        modelState = .loading
        errorMessage = nil

        do {
            try await llmManager.loadModel { [weak self] progress in
                Task { @MainActor in
                    self?.modelProgress = progress
                }
            }
            modelState = .ready
            modelProgress = 1
        } catch {
            modelState = .failed
            errorMessage = error.localizedDescription
        }
    }

    func readSelection() async {
        isReading = true
        errorMessage = nil
        defer { isReading = false }

        do {
            let selection = try await numbersBridge.getSelectedCellValues()
            selectedCells = selection
            cellRows = selection.rows
            didFinishGeneration = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generate() async {
        guard canGenerate else { return }
        isGenerating = true
        didFinishGeneration = false
        outputText = ""
        errorMessage = nil
        generationStatus = "Generating response..."
        defer { isGenerating = false }

        do {
            if modelState != .ready {
                try await loadModelForGeneration()
            }
            let result = try await llmManager.generate(cellContext: cellContext, userPrompt: prompt) { [weak self] token in
                Task { @MainActor in
                    self?.generationStatus = nil
                    self?.outputText += token
                }
            }
            guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.emptyResponse
            }
            outputText = result
            didFinishGeneration = true
            generationStatus = nil
        } catch {
            generationStatus = nil
            errorMessage = error.localizedDescription
        }
    }

    private func loadModelForGeneration() async throws {
        modelState = .loading
        modelProgress = 0
        try await llmManager.loadModel { [weak self] progress in
            Task { @MainActor in
                self?.modelProgress = progress
            }
        }
        modelState = .ready
        modelProgress = 1
    }

    func writeOutput() async {
        guard canWrite, let selectedCells else { return }
        isWriting = true
        errorMessage = nil
        defer { isWriting = false }

        do {
            let anchor = selectedCells.lastCell
            try await numbersBridge.writeValue(outputText.trimmingCharacters(in: .whitespacesAndNewlines), adjacentTo: anchor, target: writeTarget)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
