#if canImport(XCTest)
import XCTest
@testable import PreviewMD

final class ExternalChangesTests: XCTestCase {
    func testLineDiffSeparatesModifiedAddedAndRemovedHunks() throws {
        let review = try XCTUnwrap(
            ExternalChangeReview(
                originalContent: "A\nB\nC\nD\nE",
                updatedContent: "A\nB changed\nC\nInserted\nD",
                isApplied: true
            )
        )

        XCTAssertEqual(review.hunks.map(\.kind), [.modified, .added, .removed])
        XCTAssertEqual(review.hunks[0].newStart..<review.hunks[0].newEnd, 1..<2)
        XCTAssertEqual(review.hunks[1].newStart..<review.hunks[1].newEnd, 3..<4)
        XCTAssertEqual(review.hunks[2].newStart, review.hunks[2].newEnd)
    }

    func testDiffRowsExposeContextAdditionsAndRemovals() throws {
        let review = try XCTUnwrap(
            ExternalChangeReview(
                originalContent: "Heading\nOld copy\nFooter",
                updatedContent: "Heading\nNew copy\nFooter",
                isApplied: true
            )
        )

        XCTAssertTrue(review.diffRows.contains { $0.kind == .header })
        XCTAssertTrue(
            review.diffRows.contains { $0.kind == .removal && $0.text == "Old copy" }
        )
        XCTAssertTrue(
            review.diffRows.contains { $0.kind == .addition && $0.text == "New copy" }
        )
        XCTAssertTrue(
            review.diffRows.contains { $0.kind == .context && $0.text == "Heading" }
        )
    }

    func testReviewClampsSelectionWhenAFileChangesAgain() throws {
        let review = try XCTUnwrap(
            ExternalChangeReview(
                originalContent: "One\nTwo",
                updatedContent: "One changed\nTwo",
                selectedHunkIndex: 12,
                isApplied: true
            )
        )

        XCTAssertEqual(review.selectedHunkIndex, 0)
        XCTAssertTrue(review.isApplied)
    }
}
#endif
