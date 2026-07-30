#if canImport(XCTest)
import Foundation
import XCTest

final class RendererStylesTests: XCTestCase {
    func testTaskCheckboxesScaleWithTextAndUseLineCenteredPositioning() throws {
        let css = try rendererCSS()
        let checkboxRule = try declarations(
            after: """
            .task-list-item > input,
            .task-list-item > p > input
            """,
            in: css
        )

        XCTAssertTrue(checkboxRule.contains("top: calc((1lh - var(--task-checkbox-size)) / 2);"))
        XCTAssertTrue(checkboxRule.contains("width: var(--task-checkbox-size);"))
        XCTAssertTrue(checkboxRule.contains("height: var(--task-checkbox-size);"))
        XCTAssertTrue(checkboxRule.contains("margin: 0;"))
        XCTAssertTrue(checkboxRule.contains("font: inherit;"))
    }

    func testTaskCheckmarkIsCenteredInsideItsControl() throws {
        let css = try rendererCSS()
        let checkmarkRule = try declarations(
            after: """
            .task-list-item > input:checked::after,
            .task-list-item > p > input:checked::after
            """,
            in: css
        )

        XCTAssertTrue(checkmarkRule.contains("top: 50%;"))
        XCTAssertTrue(checkmarkRule.contains("left: 50%;"))
        XCTAssertTrue(checkmarkRule.contains("translate(-50%, -56%)"))
        XCTAssertTrue(checkmarkRule.contains("solid var(--page)"))
    }

    private func rendererCSS() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PreviewMD/Resources/Renderer/renderer.css")

        return try String(contentsOf: url, encoding: .utf8)
    }

    private func declarations(after selector: String, in css: String) throws -> String {
        let selectorWithBrace = selector + " {"
        let selectorRange = try XCTUnwrap(
            css.range(of: selectorWithBrace),
            "Missing CSS selector: \(selector)"
        )
        let ruleTail = css[selectorRange.upperBound...]
        let closingBrace = try XCTUnwrap(
            ruleTail.firstIndex(of: "}"),
            "Unclosed CSS rule: \(selector)"
        )
        return String(ruleTail[..<closingBrace])
    }
}
#endif
