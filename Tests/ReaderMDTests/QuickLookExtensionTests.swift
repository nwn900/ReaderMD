import Foundation
import Testing
@testable import ReaderMDQuickLook

@Suite("Quick Look extension")
struct QuickLookExtensionTests {
    @Test("Markdown decoding removes UTF-8 BOM and normalizes line endings")
    @MainActor
    func markdownDecoding() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("sample.md")
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("# Title\r\n\rBody\n".utf8))
        try data.write(to: file)

        #expect(
            try PreviewViewController.readMarkdown(from: file)
                == "# Title\n\nBody\n"
        )
    }

    @Test("Inline renderer payload cannot terminate its script element")
    func payloadEscaping() throws {
        let markdown = "</script><img src=x>&"
        let json = try QuickLookRenderer.payloadJSON(
            markdown: markdown,
            usesDarkAppearance: false
        )

        #expect(!json.contains("</script>"))
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any]
        )
        #expect(object["markdown"] as? String == markdown)
    }

    @Test("Extension declares both ReaderMD and common Markdown UTIs")
    func supportedContentTypes() throws {
        let info = try propertyList(named: "QuickLook-Info.plist")
        let extensionInfo = try #require(info["NSExtension"] as? [String: Any])
        #expect(
            extensionInfo["NSExtensionPointIdentifier"] as? String
                == "com.apple.quicklook.preview"
        )
        let attributes = try #require(
            extensionInfo["NSExtensionAttributes"] as? [String: Any]
        )
        let types = try #require(attributes["QLSupportedContentTypes"] as? [String])
        #expect(types.contains("pl.jesion.readermd.markdown"))
        #expect(types.contains("net.daringfireball.markdown"))
    }

    @Test("Application is a preferred editor for the common Markdown UTI")
    func applicationDocumentTypes() throws {
        let info = try propertyList(named: "Info.plist")
        let documentTypes = try #require(
            info["CFBundleDocumentTypes"] as? [[String: Any]]
        )
        let markdown = try #require(
            documentTypes.first { type in
                (type["LSItemContentTypes"] as? [String])?
                    .contains("pl.jesion.readermd.markdown") == true
            }
        )
        let types = try #require(markdown["LSItemContentTypes"] as? [String])
        #expect(types.contains("net.daringfireball.markdown"))
        #expect(markdown["CFBundleTypeRole"] as? String == "Editor")
        #expect(markdown["LSHandlerRank"] as? String == "Default")
    }

    @Test("Extension is sandboxed and grants WebKit only required capabilities")
    func extensionEntitlements() throws {
        let entitlements = try propertyList(named: "QuickLook.entitlements")
        #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(
            entitlements["com.apple.security.files.user-selected.read-only"] as? Bool
                == true
        )
        #expect(entitlements["com.apple.security.network.client"] as? Bool == true)
        #expect(entitlements["com.apple.security.files.user-selected.read-write"] == nil)
    }

    private func propertyList(named name: String) throws -> [String: Any] {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: projectRoot.appendingPathComponent("scripts/\(name)"))
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        )
    }
}
