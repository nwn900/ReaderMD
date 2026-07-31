#if canImport(XCTest)
import AppKit
import XCTest
@testable import PreviewMD

@MainActor
final class ToolbarItemVisibilityControllerTests: XCTestCase {
    func testSystemItemViewsStayCollapsedOnlyWhileFocusIsEnforced() async throws {
        let sidebar = NSToolbarItem.Identifier("test.sidebar")
        let displayMode = NSToolbarItem.Identifier("test.display-mode")
        let open = NSToolbarItem.Identifier("test.open")
        let search = NSToolbarItem.Identifier("test.search")
        let originalOrder = [sidebar, displayMode, open, search]

        let delegate = TestToolbarDelegate(identifiers: originalOrder)
        let toolbar = NSToolbar(identifier: "ToolbarItemVisibilityControllerTests")
        toolbar.delegate = delegate
        for identifier in originalOrder {
            toolbar.insertItem(withItemIdentifier: identifier, at: toolbar.items.count)
        }
        let originalSidebarView = try XCTUnwrap(toolbar.items[0].view)
        let originalSearchItem = try XCTUnwrap(toolbar.items[3] as? NSSearchToolbarItem)
        let originalSearchWidth = originalSearchItem.preferredWidthForSearchField

        let controller = ToolbarItemVisibilityController(identifiers: [sidebar, search])
        controller.enforceHidden(from: toolbar)
        controller.enforceHidden(from: toolbar)

        XCTAssertEqual(toolbar.items.map(\.itemIdentifier), originalOrder)
        XCTAssertFalse(toolbar.items[0].view === originalSidebarView)
        XCTAssertTrue(originalSearchItem.searchField.isHidden)
        XCTAssertEqual(originalSearchItem.preferredWidthForSearchField, 0)

        // Closing the inspector can replace a system item after focus mode has
        // already hidden the original. The replacement must be collapsed too.
        toolbar.removeItem(at: 0)
        toolbar.insertItem(withItemIdentifier: sidebar, at: 0)
        let replacementSidebarView = try XCTUnwrap(toolbar.items[0].view)
        let lateInsertionHandled = expectation(description: "late toolbar insertion hidden")
        DispatchQueue.main.async {
            lateInsertionHandled.fulfill()
        }
        await fulfillment(of: [lateInsertionHandled], timeout: 1)

        XCTAssertFalse(toolbar.items[0].view === replacementSidebarView)

        // Exiting focus restores the exact current item views and search sizing;
        // no system item has to be reconstructed through SwiftUI's delegate.
        controller.stopEnforcingHidden()

        XCTAssertEqual(toolbar.items.map(\.itemIdentifier), originalOrder)
        XCTAssertTrue(toolbar.items[0].view === replacementSidebarView)
        XCTAssertFalse(originalSearchItem.searchField.isHidden)
        XCTAssertEqual(originalSearchItem.preferredWidthForSearchField, originalSearchWidth)
    }
}

@MainActor
private final class TestToolbarDelegate: NSObject, NSToolbarDelegate {
    let identifiers: [NSToolbarItem.Identifier]

    init(identifiers: [NSToolbarItem.Identifier]) {
        self.identifiers = identifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        identifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        identifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier.rawValue == "test.search" {
            let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
            item.preferredWidthForSearchField = 180
            return item
        }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.view = NSButton(title: itemIdentifier.rawValue, target: nil, action: nil)
        return item
    }
}
#endif

