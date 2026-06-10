import Foundation

enum LLMManagerVerification {
    static func runHardcodedPrompt() async throws -> String {
        let manager = LLMManager()
        try await manager.loadModel { progress in
            print("Model download/load progress: \(Int(progress * 100))%")
        }

        var streamed = ""
        let isSummaryPrompt = CommandLine.arguments.contains("--verify-summary")
        let result = try await manager.generate(
            cellContext: isSummaryPrompt
                ? "Scrip Name\tQuantity\tAvg Buy Price\tBuy Value\tCharges and Statutory Levies\tSTT\tClosing rate\tTurnover\tShort term Unrealised P&L\tLong term Unrealised P&L\nITC\t10.0\t416.81\t4162.76\t1.02\t4.32\t280.0\t2800.0\t0.0\t-1368.11"
                : "Item\tQuantity\tPrice\nApples\t3\t2\nOranges\t4\t5",
            userPrompt: isSummaryPrompt
                ? "Summarize this data in one sentence."
                : "Return the total cost as a single number."
        ) { token in
            streamed += token
            print(token, terminator: "")
        }

        return result.isEmpty ? streamed : result
    }
}
