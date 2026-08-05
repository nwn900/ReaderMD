import AppKit
import Foundation
import UniformTypeIdentifiers

enum MarkdownFileSupport {
    static let supportedExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "txt"
    ]

    static func accepts(_ url: URL) -> Bool {
        url.isFileURL
            && supportedExtensions.contains(url.pathExtension.lowercased())
    }
}

enum MarkdownDefaultApplication {
    static let commonMarkdownType = UTType(
        importedAs: "net.daringfireball.markdown",
        conformingTo: .plainText
    )

    static var isPreviewMD: Bool {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            toOpen: commonMarkdownType
        ) else {
            return false
        }
        return Bundle(url: applicationURL)?.bundleIdentifier
            == Bundle.main.bundleIdentifier
    }

    static func makePreviewMD(
        completion: @escaping @Sendable ((any Error)?) -> Void
    ) {
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL,
            toOpen: commonMarkdownType,
            completion: completion
        )
    }
}

enum DisplayMode: String, CaseIterable, Identifiable {
    case preview
    case split
    case source

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: "Document"
        case .split: "Split"
        case .source: "Source"
        }
    }

    var symbol: String {
        switch self {
        case .preview: "doc.richtext"
        case .split: "rectangle.split.2x1"
        case .source: "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum DocumentEditOrigin: Equatable {
    case source
    case richEditor
}

enum PreviewTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

enum ReadingStyle: String, CaseIterable, Identifiable {
    case modern
    case classic
    case editorial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern: "Modern"
        case .classic: "Classic"
        case .editorial: "Editorial"
        }
    }

    var subtitle: String {
        switch self {
        case .modern: "Clean system typography"
        case .classic: "Warm, literary serif"
        case .editorial: "Serif headlines, crisp body"
        }
    }

    var symbol: String {
        switch self {
        case .modern: "textformat"
        case .classic: "character.book.closed"
        case .editorial: "newspaper"
        }
    }
}

enum ReadingWidth: String, CaseIterable, Identifiable {
    case narrow
    case comfortable
    case wide
    case data
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .narrow: "Narrow"
        case .comfortable: "Comfortable"
        case .wide: "Wide"
        case .data: "Table / Data"
        case .custom: "Custom"
        }
    }

    var cssValue: Int {
        switch self {
        case .narrow: 680
        case .comfortable: 820
        case .wide: 1060
        case .data: 1440
        case .custom: 820
        }
    }

    var symbol: String {
        switch self {
        case .narrow: "text.alignleft"
        case .comfortable: "doc.text"
        case .wide: "arrow.left.and.right"
        case .data: "tablecells"
        case .custom: "slider.horizontal.3"
        }
    }
}

struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var title: String
    var content: String
    var lastSavedContent: String
    /// Monotonically increasing in-memory revision shared by the source and
    /// rich editors. It prevents an edit echoed back from SwiftUI from
    /// rebuilding the web editor and moving its selection.
    var contentRevision = 0
    var fileFormat = MarkdownFileFormat.standard
    var diskSnapshot: FileSnapshot?
    var undoHistory: [String] = []
    var redoHistory: [String] = []
    var lastEditOrigin: DocumentEditOrigin?
    var lastEditAt: Date?
    var openedAt: Date
    var fileModifiedAt: Date?
    var isPinned: Bool
    var isSample: Bool

    var isDirty: Bool {
        content != lastSavedContent
    }

    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    var characterCount: Int {
        content.count
    }

    var readingMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 220.0)))
    }

    var displayPath: String {
        guard let url else { return isSample ? "Built-in showcase" : "Unsaved document" }
        return url.deletingLastPathComponent().path(percentEncoded: false)
    }
}

struct RecentDocument: Codable, Identifiable, Equatable {
    var path: String
    var lastOpened: Date
    var isPinned: Bool

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var title: String { url.deletingPathExtension().lastPathComponent }
}

struct OutlineHeading: Identifiable, Equatable {
    let id: String
    let level: Int
    let title: String
}

enum MarkdownOutline {
    static func headings(in markdown: String) -> [OutlineHeading] {
        var headings: [OutlineHeading] = []
        var insideFence = false
        var fenceMarker = ""

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if insideFence, marker == fenceMarker {
                    insideFence = false
                    fenceMarker = ""
                } else if !insideFence {
                    insideFence = true
                    fenceMarker = marker
                }
                continue
            }

            guard !insideFence else { continue }

            var hashCount = 0
            for character in line {
                if character == "#", hashCount < 6 {
                    hashCount += 1
                } else {
                    break
                }
            }

            guard hashCount > 0,
                  line.dropFirst(hashCount).first?.isWhitespace == true
            else { continue }

            var title = String(line.dropFirst(hashCount))
                .trimmingCharacters(in: .whitespaces)
            title = title.replacingOccurrences(
                of: #"\s+#+\s*$"#,
                with: "",
                options: .regularExpression
            )
            title = title.replacingOccurrences(
                of: #"[*_`~\[\]]"#,
                with: "",
                options: .regularExpression
            )

            guard !title.isEmpty else { continue }
            headings.append(
                OutlineHeading(
                    id: "heading-\(headings.count)",
                    level: hashCount,
                    title: title
                )
            )
        }

        return headings
    }
}
