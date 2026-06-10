import Foundation
import SwiftUI

@main
struct NumbersWingmanApp: App {
    init() {
        if CommandLine.arguments.contains("--verify-llm") {
            Task.detached {
                do {
                    let result = try await LLMManagerVerification.runHardcodedPrompt()
                    print("\n\nVerification result:\n\(result)")
                    Foundation.exit(0)
                } catch {
                    fputs("Verification failed: \(error.localizedDescription)\n", stderr)
                    Foundation.exit(1)
                }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Numbers Wingman", systemImage: "tablecells") {
            MenuBarView()
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}
