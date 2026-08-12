import Foundation

struct MarkdownFileFormat: Equatable {
    enum LineEnding: Equatable {
        case lineFeed
        case carriageReturnLineFeed
        case carriageReturn

        var value: String {
            switch self {
            case .lineFeed: "\n"
            case .carriageReturnLineFeed: "\r\n"
            case .carriageReturn: "\r"
            }
        }
    }

    var lineEnding: LineEnding
    var hasUTF8ByteOrderMark: Bool

    static let standard = Self(
        lineEnding: .lineFeed,
        hasUTF8ByteOrderMark: false
    )
}

struct FileSnapshot: Equatable {
    let modificationDate: Date?
    let size: Int
    let fingerprint: UInt64

    static func capture(url: URL, data: Data? = nil) throws -> Self {
        let contents = try data ?? Data(contentsOf: url)
        let values = try url.resourceValues(
            forKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        return Self(
            modificationDate: values.contentModificationDate,
            size: values.fileSize ?? contents.count,
            fingerprint: fingerprint(for: contents)
        )
    }

    private static func fingerprint(for data: Data) -> UInt64 {
        // Stable FNV-1a is sufficient here: this is an external-change guard,
        // not a cryptographic integrity check.
        data.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

enum MarkdownFileIO {
    struct ReadResult {
        let content: String
        let format: MarkdownFileFormat
        let snapshot: FileSnapshot
    }

    static func read(from url: URL) throws -> ReadResult {
        let data = try Data(contentsOf: url)
        let hasBOM = data.starts(with: [0xEF, 0xBB, 0xBF])
        let textData = hasBOM ? data.dropFirst(3) : data[...]

        guard let decoded = String(data: textData, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        let lineEnding = dominantLineEnding(in: decoded)
        let normalized = decoded
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return ReadResult(
            content: normalized,
            format: MarkdownFileFormat(
                lineEnding: lineEnding,
                hasUTF8ByteOrderMark: hasBOM
            ),
            snapshot: try FileSnapshot.capture(url: url, data: data)
        )
    }

    @discardableResult
    static func write(
        _ content: String,
        to url: URL,
        format: MarkdownFileFormat
    ) throws -> FileSnapshot {
        let encodedText: String
        if format.lineEnding == .lineFeed {
            encodedText = content
        } else {
            encodedText = content.replacingOccurrences(
                of: "\n",
                with: format.lineEnding.value
            )
        }

        guard var data = encodedText.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        if format.hasUTF8ByteOrderMark {
            data.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0)
        }

        try data.write(to: url, options: .atomic)
        return try FileSnapshot.capture(url: url, data: data)
    }

    private static func dominantLineEnding(
        in text: String
    ) -> MarkdownFileFormat.LineEnding {
        let crlfCount = text.components(separatedBy: "\r\n").count - 1
        let withoutCRLF = text.replacingOccurrences(of: "\r\n", with: "")
        let crCount = withoutCRLF.filter { $0 == "\r" }.count
        let lfCount = withoutCRLF.filter { $0 == "\n" }.count

        if crlfCount >= max(crCount, lfCount), crlfCount > 0 {
            return .carriageReturnLineFeed
        }
        if crCount > lfCount {
            return .carriageReturn
        }
        return .lineFeed
    }
}
