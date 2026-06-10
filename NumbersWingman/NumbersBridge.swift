import Foundation

actor NumbersBridge {
    func getSelectedCellValues() async throws -> CellSelection {
        let source = """
        tell application "Numbers"
            if not (exists front document) then error "No Numbers document is open."
            tell front document
                tell active sheet
                    set tbl to first table whose class of selection range is range
                    set selRange to selection range of tbl
                    set startRow to address of row of first cell of selRange
                    set startColumn to address of column of first cell of selRange
                    set rowCount to count of rows of selRange
                    set columnCount to count of columns of selRange
                    set flatValues to {}
                    repeat with c in every cell of selRange
                        set cellVal to value of c
                        if cellVal is missing value then
                            set end of flatValues to ""
                        else
                            set end of flatValues to (cellVal as string)
                        end if
                    end repeat
                    return {startRow, startColumn, rowCount, columnCount, flatValues}
                end tell
            end tell
        end tell
        """

        let descriptor = try await runAppleScript(source)
        return try parseSelection(from: descriptor)
    }

    func writeValue(_ text: String, adjacentTo lastCell: CellAddress, target: WriteTarget) async throws {
        let targetRow: Int
        let targetColumn: Int

        switch target {
        case .nextColumn:
            targetRow = lastCell.row
            targetColumn = lastCell.column + 1
        case .nextRow:
            targetRow = lastCell.row + 1
            targetColumn = lastCell.column
        }

        let source = """
        tell application "Numbers"
            if not (exists front document) then error "No Numbers document is open."
            tell front document
                tell active sheet
                    tell first table
                        set value of cell \(targetRow) of column \(targetColumn) to "\(text.appleScriptEscaped)"
                    end tell
                end tell
            end tell
        end tell
        """

        _ = try await runAppleScript(source)
    }

    private func runAppleScript(_ source: String) async throws -> NSAppleEventDescriptor {
        try await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw NumbersError.scriptFailed("Could not compile AppleScript.")
            }

            let result = script.executeAndReturnError(&error)
            if let error {
                if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
                    throw NumbersError.appleEventsPermissionDenied
                }
                throw NumbersError.scriptFailed(error.description)
            }

            return result
        }.value
    }

    private func parseSelection(from descriptor: NSAppleEventDescriptor) throws -> CellSelection {
        guard descriptor.numberOfItems == 5,
              let startRow = descriptor.atIndex(1)?.int32Value,
              let startColumn = descriptor.atIndex(2)?.int32Value,
              let rowCount = descriptor.atIndex(3)?.int32Value,
              let columnCount = descriptor.atIndex(4)?.int32Value,
              let valuesDescriptor = descriptor.atIndex(5)
        else {
            throw NumbersError.invalidScriptResult
        }

        let rows = Int(rowCount)
        let columns = Int(columnCount)
        guard rows > 0, columns > 0 else {
            throw NumbersError.invalidSelection
        }

        var flatValues: [String] = []
        for index in 1...valuesDescriptor.numberOfItems {
            flatValues.append(valuesDescriptor.atIndex(index)?.stringValue ?? "")
        }

        var groupedRows: [[String]] = []
        for rowIndex in 0..<rows {
            let start = rowIndex * columns
            let end = min(start + columns, flatValues.count)
            groupedRows.append(Array(flatValues[start..<end]))
        }

        return CellSelection(
            rows: groupedRows,
            lastCell: CellAddress(row: Int(startRow) + rows - 1, column: Int(startColumn) + columns - 1)
        )
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
