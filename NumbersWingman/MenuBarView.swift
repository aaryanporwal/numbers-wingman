import SwiftUI

struct MenuBarView: View {
    @State private var viewModel = MenuBarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ModelStatusBar(viewModel: viewModel)

            CellGridPanel(title: "Selected Cells", rows: viewModel.cellRows, placeholder: "No cells loaded.")

            VStack(alignment: .leading, spacing: 6) {
                Text("Instruction")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.prompt)
                    .font(.body)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            TextPanel(
                title: "Response",
                text: viewModel.outputText,
                placeholder: viewModel.generationStatus ?? "Generated output appears here."
            )

            Picker("Write to", selection: $viewModel.writeTarget) {
                ForEach(WriteTarget.allCases) { target in
                    Text(target.label).tag(target)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Button("Read Selection") {
                    Task { await viewModel.readSelection() }
                }
                .disabled(viewModel.isBusy)

                Button("Generate") {
                    Task { await viewModel.generate() }
                }
                .disabled(!viewModel.canGenerate)

                Button("Write") {
                    Task { await viewModel.writeOutput() }
                }
                .disabled(!viewModel.canWrite)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
    }
}

private struct ModelStatusBar: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if viewModel.modelState == .loading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(viewModel.modelState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if viewModel.modelState == .loading {
                ProgressView(value: viewModel.modelProgress)
            }
        }
    }
}

private struct CellGridPanel: View {
    let title: String
    let rows: [[String]]
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView([.horizontal, .vertical]) {
                if rows.isEmpty {
                    Text(placeholder)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            GridRow {
                                ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
                                    Text(rows[rowIndex][columnIndex])
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .frame(minWidth: 44, maxWidth: .infinity, alignment: .leading)
                                        .background(Color(nsColor: .textBackgroundColor))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .separatorColor))
                    .padding(8)
                }
            }
            .frame(minHeight: 74, maxHeight: 120)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct TextPanel: View {
    let title: String
    let text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 74, maxHeight: 120)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    MenuBarView()
        .frame(width: 360)
}
