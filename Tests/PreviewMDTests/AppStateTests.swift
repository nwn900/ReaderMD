#if canImport(XCTest)
import AppKit
import Foundation
import XCTest
@testable import PreviewMD

@MainActor
final class AppStateTests: XCTestCase {
    func testFreshAppStartsWithAnEmptyWorkspace() throws {
        let state = try makeState()

        XCTAssertTrue(state.documents.isEmpty)
        XCTAssertNil(state.selectedDocumentID)
        XCTAssertNil(state.currentDocument)
        XCTAssertEqual(state.sidebarSelection, "")
    }

    func testClosingTheOnlyTabLeavesAnEmptyWorkspace() throws {
        let state = try makeState()
        state.openWelcome()
        let initialDocument = try XCTUnwrap(state.currentDocument)

        state.closeTab(initialDocument.id)

        XCTAssertTrue(state.documents.isEmpty)
        XCTAssertNil(state.selectedDocumentID)
        XCTAssertNil(state.currentDocument)
        XCTAssertEqual(state.sidebarSelection, "")
    }

    func testPaperCanvasDefaultsToHidden() throws {
        let state = try makeState()

        XCTAssertFalse(state.usesPaperCanvas)
    }

    func testReadingStyleDefaultsToModern() throws {
        let state = try makeState()

        XCTAssertEqual(state.readingStyle, .modern)
    }

    func testReadingStylePersists() throws {
        let suiteName = "PreviewMDTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        state.readingStyle = .classic
        state.updatePreferences()

        let restoredState = AppState(defaults: defaults)
        XCTAssertEqual(restoredState.readingStyle, .classic)
    }

    func testShowcaseDocumentIsEmbeddedInTheExecutable() throws {
        let state = try makeState()

        state.openWelcome()

        let document = try XCTUnwrap(state.currentDocument)
        XCTAssertTrue(document.isSample)
        XCTAssertEqual(document.content, ShowcaseDocument.markdown)
        XCTAssertTrue(document.content.contains("```mermaid"))
        XCTAssertTrue(document.content.contains("| Native macOS shell |"))
    }

    func testCustomReadingWidthIsClamped() throws {
        let state = try makeState()

        state.setCustomReadingWidth(2_000)

        XCTAssertEqual(state.readingWidth, .custom)
        XCTAssertEqual(state.effectiveReadingWidth, 1_600)

        state.setCustomReadingWidth(400)

        XCTAssertEqual(state.effectiveReadingWidth, 560)
    }

    func testFitWideContentUsesTablePreset() throws {
        let state = try makeState()

        state.fitWideContent()

        XCTAssertEqual(state.readingWidth, .data)
        XCTAssertEqual(state.effectiveReadingWidth, 1_440)
    }

    func testDropFilterAcceptsOnlySupportedLocalFiles() {
        XCTAssertTrue(
            MarkdownFileSupport.accepts(URL(fileURLWithPath: "/tmp/readme.md"))
        )
        XCTAssertTrue(
            MarkdownFileSupport.accepts(URL(fileURLWithPath: "/tmp/notes.MARKDOWN"))
        )
        XCTAssertFalse(
            MarkdownFileSupport.accepts(URL(fileURLWithPath: "/tmp/archive.pdf"))
        )
        XCTAssertFalse(
            MarkdownFileSupport.accepts(URL(string: "https://example.com/readme.md")!)
        )
    }

    func testRendererShellStartsWithCurrentAppearance() {
        let payload = MarkdownWebView.RenderPayload(
            markdown: "# Current settings",
            theme: PreviewTheme.dark.rawValue,
            readingStyle: ReadingStyle.classic.rawValue,
            systemDark: false,
            readingWidth: 1_440,
            paperCanvas: false,
            zoom: 1.2,
            searchText: "",
            outlineTarget: nil
        )

        let html = RendererAssets.shellHTML(for: payload)

        XCTAssertTrue(
            html.contains(
                #"<html lang="en" data-theme="dark" data-style="classic" data-paper="false" style="--reading-width: 1440px">"#
            )
        )
    }

    func testDockOpenRequestWaitsForAppState() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewMD-\(UUID().uuidString).md")
        try "# Opened from Dock".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let delegate = AppDelegate()
        delegate.application(NSApplication.shared, open: [fileURL])

        let state = try makeState()
        delegate.state = state

        XCTAssertEqual(state.currentDocument?.url?.standardizedFileURL, fileURL.standardizedFileURL)
        XCTAssertEqual(state.currentDocument?.content, "# Opened from Dock")
    }

    private func makeState() throws -> AppState {
        let suiteName = "PreviewMDTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return AppState(defaults: defaults)
    }
}
#endif
