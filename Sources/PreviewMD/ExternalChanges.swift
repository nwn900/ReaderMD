import Foundation

enum ExternalChangeKind: String, Codable, Equatable {
    case added
    case modified
    case removed
}

struct ExternalChangeHunk: Codable, Equatable, Identifiable {
    let oldStart: Int
    let oldEnd: Int
    let newStart: Int
    let newEnd: Int
    let kind: ExternalChangeKind

    var id: String {
        "\(oldStart):\(oldEnd):\(newStart):\(newEnd):\(kind.rawValue)"
    }

    var oldLineCount: Int { oldEnd - oldStart }
    var newLineCount: Int { newEnd - newStart }
}

struct ExternalChangeReview: Equatable, Identifiable {
    let id: UUID
    let originalContent: String
    let updatedContent: String
    let hunks: [ExternalChangeHunk]
    var selectedHunkIndex: Int
    var isApplied: Bool

    init?(
        id: UUID = UUID(),
        originalContent: String,
        updatedContent: String,
        selectedHunkIndex: Int = 0,
        isApplied: Bool
    ) {
        guard originalContent != updatedContent else { return nil }
        let hunks = ExternalChangeDiff.hunks(
            from: originalContent,
            to: updatedContent
        )
        guard !hunks.isEmpty else { return nil }

        self.id = id
        self.originalContent = originalContent
        self.updatedContent = updatedContent
        self.hunks = hunks
        self.selectedHunkIndex = min(
            max(0, selectedHunkIndex),
            hunks.count - 1
        )
        self.isApplied = isApplied
    }

    var selectedHunk: ExternalChangeHunk? {
        guard hunks.indices.contains(selectedHunkIndex) else { return nil }
        return hunks[selectedHunkIndex]
    }

    var diffRows: [ExternalDiffRow] {
        ExternalChangeDiff.rows(
            oldContent: originalContent,
            newContent: updatedContent,
            hunks: hunks
        )
    }
}

enum ExternalDiffRowKind: Equatable {
    case header
    case context
    case addition
    case removal
}

struct ExternalDiffRow: Identifiable, Equatable {
    let id: Int
    let kind: ExternalDiffRowKind
    let oldLine: Int?
    let newLine: Int?
    let text: String
}

enum ExternalChangeDiff {
    static func hunks(from oldContent: String, to newContent: String) -> [ExternalChangeHunk] {
        let oldLines = lines(in: oldContent)
        let newLines = lines(in: newContent)
        let difference = newLines.difference(from: oldLines)
        let removals = Set(difference.compactMap { change -> Int? in
            guard case let .remove(offset, _, _) = change else { return nil }
            return offset
        })
        let insertions = Set(difference.compactMap { change -> Int? in
            guard case let .insert(offset, _, _) = change else { return nil }
            return offset
        })

        var oldIndex = 0
        var newIndex = 0
        var result: [ExternalChangeHunk] = []

        while oldIndex < oldLines.count || newIndex < newLines.count {
            let beginsChange = removals.contains(oldIndex) || insertions.contains(newIndex)
            if !beginsChange {
                oldIndex += oldIndex < oldLines.count ? 1 : 0
                newIndex += newIndex < newLines.count ? 1 : 0
                continue
            }

            let oldStart = oldIndex
            let newStart = newIndex
            var removedCount = 0
            var insertedCount = 0

            while removals.contains(oldIndex) || insertions.contains(newIndex) {
                if removals.contains(oldIndex) {
                    oldIndex += 1
                    removedCount += 1
                }
                if insertions.contains(newIndex) {
                    newIndex += 1
                    insertedCount += 1
                }
            }

            let kind: ExternalChangeKind
            if removedCount == 0 {
                kind = .added
            } else if insertedCount == 0 {
                kind = .removed
            } else {
                kind = .modified
            }
            result.append(
                ExternalChangeHunk(
                    oldStart: oldStart,
                    oldEnd: oldStart + removedCount,
                    newStart: newStart,
                    newEnd: newStart + insertedCount,
                    kind: kind
                )
            )
        }

        return result
    }

    static func rows(
        oldContent: String,
        newContent: String,
        hunks: [ExternalChangeHunk],
        context: Int = 2
    ) -> [ExternalDiffRow] {
        let oldLines = lines(in: oldContent)
        let newLines = lines(in: newContent)
        var rows: [ExternalDiffRow] = []

        func append(
            _ kind: ExternalDiffRowKind,
            oldLine: Int? = nil,
            newLine: Int? = nil,
            text: String
        ) {
            rows.append(
                ExternalDiffRow(
                    id: rows.count,
                    kind: kind,
                    oldLine: oldLine,
                    newLine: newLine,
                    text: text
                )
            )
        }

        for hunk in hunks {
            let oldLocation = hunk.oldStart + 1
            let newLocation = hunk.newStart + 1
            append(
                .header,
                text: "@@ -\(oldLocation),\(hunk.oldLineCount) +\(newLocation),\(hunk.newLineCount) @@"
            )

            let leadingCount = min(context, hunk.oldStart, hunk.newStart)
            if leadingCount > 0 {
                for offset in 0..<leadingCount {
                    let oldIndex = hunk.oldStart - leadingCount + offset
                    let newIndex = hunk.newStart - leadingCount + offset
                    append(
                        .context,
                        oldLine: oldIndex + 1,
                        newLine: newIndex + 1,
                        text: oldLines[oldIndex]
                    )
                }
            }

            if hunk.oldLineCount > 0 {
                for index in hunk.oldStart..<hunk.oldEnd {
                    append(.removal, oldLine: index + 1, text: oldLines[index])
                }
            }
            if hunk.newLineCount > 0 {
                for index in hunk.newStart..<hunk.newEnd {
                    append(.addition, newLine: index + 1, text: newLines[index])
                }
            }

            let trailingCount = min(
                context,
                oldLines.count - hunk.oldEnd,
                newLines.count - hunk.newEnd
            )
            if trailingCount > 0 {
                for offset in 0..<trailingCount {
                    let oldIndex = hunk.oldEnd + offset
                    let newIndex = hunk.newEnd + offset
                    append(
                        .context,
                        oldLine: oldIndex + 1,
                        newLine: newIndex + 1,
                        text: newLines[newIndex]
                    )
                }
            }
        }

        return rows
    }

    private static func lines(in content: String) -> [String] {
        content.components(separatedBy: "\n")
    }
}
