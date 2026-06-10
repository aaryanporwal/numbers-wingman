import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

actor LLMManager {
    private enum LoadState {
        case idle
        case loading(Task<ModelContainer, Error>)
        case loaded(ModelContainer)
    }

    private static let modelConfiguration = ModelConfiguration(
        id: "mlx-community/Phi-4-mini-instruct-4bit",
        extraEOSTokens: ["<|end|>", "<|endoftext|>"]
    )
    private static let instructions = """
    You are a spreadsheet data assistant. You receive cell data and an instruction.
    Reply with only the requested value or summary, suitable for pasting into a spreadsheet cell.
    Do not include markdown, labels, or explanations.
    """

    private var loadState = LoadState.idle

    func loadModel(progressHandler: @escaping @Sendable (Double) -> Void) async throws {
        _ = try await modelContainer(progressHandler: progressHandler)
    }

    func generate(
        cellContext: String,
        userPrompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let container = try await modelContainer { _ in }
        let session = ChatSession(
            container,
            instructions: Self.instructions,
            generateParameters: GenerateParameters(maxTokens: 384, temperature: 0.0)
        )
        let prompt = Self.prompt(cellContext: cellContext, userPrompt: userPrompt)

        var rawOutput = ""
        for try await token in session.streamResponse(to: prompt) {
            rawOutput += token
            if Self.hasStopMarker(rawOutput) {
                break
            }
            onToken(token)
        }

        return Self.cleanOutput(rawOutput)
    }

    private func modelContainer(progressHandler: @escaping @Sendable (Double) -> Void) async throws -> ModelContainer {
        switch loadState {
        case .idle:
            progressHandler(0)
            let task = Task {
                try await LLMModelFactory.shared.loadContainer(
                    from: HubDownloader(),
                    using: TransformersTokenizerLoader(),
                    configuration: Self.modelConfiguration
                ) { progress in
                    progressHandler(progress.fractionCompleted)
                }
            }
            loadState = .loading(task)

            do {
                let container = try await task.value
                loadState = .loaded(container)
                progressHandler(1)
                return container
            } catch {
                loadState = .idle
                throw error
            }

        case .loading(let task):
            let container = try await task.value
            progressHandler(1)
            return container

        case .loaded(let container):
            progressHandler(1)
            return container
        }
    }

    private static func prompt(cellContext: String, userPrompt: String) -> String {
        """
        Cell data:
        \(formattedCellContext(cellContext))

        Instruction:
        \(userPrompt)
        """
    }

    private static func formattedCellContext(_ cellContext: String) -> String {
        let rows = cellContext
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard rows.count >= 2 else { return cellContext }

        let headers = rows[0].components(separatedBy: "\t").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard headers.count > 1, !headers.contains(where: \.isEmpty) else {
            return cellContext
        }

        let formattedRows = rows.dropFirst().enumerated().map { rowIndex, row in
            let values = row.components(separatedBy: "\t").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let pairs = headers.indices.compactMap { index -> String? in
                guard index < values.count, !values[index].isEmpty else { return nil }
                return "\(headers[index]) = \(values[index])"
            }
            return "Row \(rowIndex + 1): \(pairs.joined(separator: "; "))"
        }

        return formattedRows.joined(separator: "\n")
    }

    private static let generationStopMarkers = ["<|end|>", "<|endoftext|>", "<|user|>", "<|assistant|>"]

    private static func hasStopMarker(_ text: String) -> Bool {
        generationStopMarkers.contains { text.contains($0) }
    }

    private static func cleanOutput(_ text: String) -> String {
        var result = text
        for marker in generationStopMarkers {
            if let range = result.range(of: marker) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct HubDownloader: MLXLMCommon.Downloader {
    private let upstream: HuggingFace.HubClient

    init(_ upstream: HuggingFace.HubClient = .default) {
        self.upstream = upstream
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = HuggingFace.Repo.ID(rawValue: id) else {
            throw LLMError.invalidModelRepository(id)
        }

        return try await upstream.downloadSnapshot(
            of: repoID,
            revision: revision ?? "main",
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}

private struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(tokenizer)
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
