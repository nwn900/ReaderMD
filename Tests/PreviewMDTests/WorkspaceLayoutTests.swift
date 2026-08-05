#if canImport(XCTest)
import Foundation
import XCTest

final class WorkspaceLayoutTests: XCTestCase {
    func testStableDocumentWorkspaceLetsFocusBlurReachToolbarRegion() throws {
        let source = try workspaceSource()
        let workspaceStart = try XCTUnwrap(
            source.range(of: "private struct DocumentWorkspace")
        )
        let workspaceTail = source[workspaceStart.lowerBound...]
        let workspaceEnd = try XCTUnwrap(
            workspaceTail.range(of: "private struct SplitDivider")
        )
        let workspace = String(workspaceTail[..<workspaceEnd.lowerBound])

        XCTAssertTrue(workspace.contains(".ignoresSafeArea("))
        XCTAssertTrue(
            workspace.contains("state.isFocusMode ? .container : []")
        )
        XCTAssertTrue(workspace.contains("edges: .top"))
    }

    func testSidebarKeepsBrandButDoesNotAdvertiseShowcase() throws {
        let source = try workspaceSource()
        let sidebarStart = try XCTUnwrap(
            source.range(of: "private struct SidebarView")
        )
        let sidebarTail = source[sidebarStart.lowerBound...]
        let sidebarEnd = try XCTUnwrap(
            sidebarTail.range(of: "private struct FolderSectionHeader")
        )
        let sidebar = String(sidebarTail[..<sidebarEnd.lowerBound])

        XCTAssertTrue(sidebar.contains("BrandHeader()"))
        XCTAssertFalse(sidebar.contains("Showcase"))
        XCTAssertFalse(sidebar.contains("openWelcome"))
    }

    private func workspaceSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PreviewMD/WorkspaceView.swift")

        return try String(contentsOf: url, encoding: .utf8)
    }
}
#endif
