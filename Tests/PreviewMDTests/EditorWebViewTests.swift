#if canImport(XCTest)
import Foundation
import WebKit
import XCTest
@testable import PreviewMD

@MainActor
final class EditorWebViewTests: XCTestCase, WKNavigationDelegate {
    private var navigationExpectation: XCTestExpectation?

    func testLocalImagePickerBuildsPortableMarkdownPaths() {
        let documentURL = URL(fileURLWithPath: "/Users/example/project/docs/readme.md")
        let imageURL = URL(
            fileURLWithPath: "/Users/example/project/assets/My Image (1).png"
        )

        XCTAssertEqual(
            MarkdownWebView.Coordinator.markdownImageSource(
                for: imageURL,
                relativeTo: documentURL
            ),
            "../assets/My%20Image%20%281%29.png"
        )
        XCTAssertEqual(
            MarkdownWebView.Coordinator.markdownImageSource(
                for: imageURL,
                relativeTo: nil
            ),
            "file:///Users/example/project/assets/My%20Image%20(1).png"
        )
    }

    func testLocalFileURLImageRendersAndRoundTrips() async throws {
        let markdown = "![Local icon](file:///tmp/AppIcon.svg)\n"
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            """
            const image = document.querySelector("#preview-document img");
            return {
              hasImage: image !== null,
              source: image && image.getAttribute("src"),
              markdown: window.previewmdSerializeEditor(),
            };
            """,
            contentWorld: .page
        )
        let response = try XCTUnwrap(result as? [String: Any])

        XCTAssertEqual(response["hasImage"] as? Bool, true)
        XCTAssertEqual(response["source"] as? String, "file:///tmp/AppIcon.svg")
        XCTAssertEqual(response["markdown"] as? String, markdown)
    }

    func testRichSelectionSerializesAsBoldMarkdown() async throws {
        let webView = try await makeEditor(markdown: "Hello world.\n")

        let result = try await webView.callAsyncJavaScript(
            """
            const paragraph = document.querySelector("#preview-document p");
            const text = paragraph.firstChild;
            const start = text.nodeValue.indexOf("world");
            const range = document.createRange();
            range.setStart(text, start);
            range.setEnd(text, start + "world".length);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            document.execCommand("bold", false, null);
            return window.previewmdFlushEditor();
            """,
            contentWorld: .page
        )

        XCTAssertEqual(result as? String, "Hello **world**.\n")
    }

    func testFlushWithoutEditsReturnsExactSource() async throws {
        let markdown = """
        # Exact source

        A [reference link][docs] with deliberate spacing.\u{20}\u{20}
        Next line.

        [docs]: guide.md "Guide"
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            "return window.previewmdFlushEditor();",
            contentWorld: .page
        )

        XCTAssertEqual(result as? String, markdown)
    }

    func testComplexRenderedObjectsRoundTripToMarkdown() async throws {
        let markdown = """
        # Objects

        - [ ] Task

        | Name | Value |
        | --- | ---: |
        | Alpha | 1 |

        ```swift
        let value = 1
        ```

        ```mermaid
        flowchart LR
          A --> B
        ```

        Inline math: $a^2 + b^2$.
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            "return window.previewmdSerializeEditor();",
            contentWorld: .page
        )
        let serialized = try XCTUnwrap(result as? String)

        XCTAssertTrue(serialized.contains("- [ ] Task"))
        XCTAssertTrue(serialized.contains("| Name | Value |"))
        XCTAssertTrue(serialized.contains("| --- | ---: |"))
        XCTAssertTrue(serialized.contains("```swift\nlet value = 1\n```"))
        XCTAssertTrue(serialized.contains("```mermaid\nflowchart LR\n  A --> B\n```"))
        XCTAssertTrue(serialized.contains("Inline math: $a^2 + b^2$."))
    }

    func testTaskAndTableEditsSerializeBackToSource() async throws {
        let markdown = """
        - [ ] Ship it

        | Name | Value |
        | --- | --- |
        | Alpha | 1 |
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            """
            document.querySelector('input[type="checkbox"]').checked = true;
            const rows = Array.from(document.querySelectorAll("table tr"));
            rows.forEach((row) => row.cells[1].style.textAlign = "right");
            const bodyRow = rows[rows.length - 1];
            const next = bodyRow.cloneNode(true);
            next.cells[0].textContent = "Beta";
            next.cells[1].textContent = "2";
            bodyRow.parentNode.appendChild(next);
            return window.previewmdSerializeEditor();
            """,
            contentWorld: .page
        )
        let serialized = try XCTUnwrap(result as? String)

        XCTAssertTrue(serialized.contains("- [x] Ship it"))
        XCTAssertTrue(serialized.contains("| --- | ---: |"))
        XCTAssertTrue(serialized.contains("| Beta | 2 |"))
    }

    func testLinksImagesAlertsAndNamedFootnotesKeepMarkdownMeaning() async throws {
        let markdown = """
        Read [the guide](guide.md).

        ![Diagram](images/diagram.png "Architecture")

        > [!NOTE]
        > Keep this safe.

        A named reference.[^details]

        [^details]: Footnote text.
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            "return window.previewmdSerializeEditor();",
            contentWorld: .page
        )
        let serialized = try XCTUnwrap(result as? String)

        XCTAssertTrue(serialized.contains("[the guide](guide.md)"))
        XCTAssertTrue(
            serialized.contains(
                #"![Diagram](images/diagram.png "Architecture")"#
            )
        )
        XCTAssertTrue(serialized.contains("> [!NOTE]\n> Keep this safe."))
        XCTAssertTrue(serialized.contains("A named reference.[^details]"))
        XCTAssertTrue(serialized.contains("[^details]: Footnote text."))
    }

    func testEmptyLineShowsCompleteMarkdownInserter() async throws {
        let webView = try await makeEditor(markdown: "")
        let result = try await webView.callAsyncJavaScript(
            """
            const paragraph = document.querySelector("#preview-document p");
            const range = document.createRange();
            range.selectNodeContents(paragraph);
            range.collapse(true);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            window.previewmdUpdateBlockInserter();
            return {
              visible: !document.querySelector("#block-inserter").hidden,
              blocks: window.previewmdAvailableBlocks(),
            };
            """,
            contentWorld: .page
        )
        let response = try XCTUnwrap(result as? [String: Any])

        XCTAssertEqual(response["visible"] as? Bool, true)
        XCTAssertEqual(
            Set(try XCTUnwrap(response["blocks"] as? [String])),
            Set([
                "text",
                "heading-1",
                "heading-2",
                "heading-3",
                "heading-4",
                "heading-5",
                "heading-6",
                "quote",
                "bullet-list",
                "numbered-list",
                "task-list",
                "table",
                "code",
                "mermaid",
                "image",
                "image-url",
                "link",
                "math",
                "divider",
                "alert-note",
                "alert-tip",
                "alert-important",
                "alert-warning",
                "alert-caution",
                "footnote",
                "raw-markdown",
            ])
        )
    }

    func testPressingReturnShowsInserterBesideTheNewEmptyLine() async throws {
        let webView = try await makeEditor(markdown: "First line\n")
        let result = try await webView.callAsyncJavaScript(
            """
            const paragraph = document.querySelector("#preview-document p");
            const range = document.createRange();
            range.selectNodeContents(paragraph);
            range.collapse(false);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            document.execCommand("insertParagraph", false, null);
            window.previewmdUpdateBlockInserter();

            const inserter = document.querySelector("#block-inserter");
            const emptyBlocks = Array.from(
              document.querySelector("#preview-document").children
            ).filter((node) => !(node.textContent || "").trim());
            return {
              visible: !inserter.hidden,
              emptyBlockCount: emptyBlocks.length,
            };
            """,
            contentWorld: .page
        )
        let response = try XCTUnwrap(result as? [String: Any])

        XCTAssertEqual(response["visible"] as? Bool, true)
        XCTAssertEqual(response["emptyBlockCount"] as? Int, 1)
    }

    func testArrowKeysTraverseTextAndRenderedObjectsInDocumentOrder() async throws {
        let markdown = """
        Before

        ![Local icon](file:///tmp/AppIcon.svg)

        | Name | Value |
        | --- | --- |
        | Alpha | 1 |

        ```swift
        let value = 1
        ```

        After
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            """
            const article = document.querySelector("#preview-document");
            const before = Array.from(article.querySelectorAll("p"))
              .find((node) => node.textContent.trim() === "Before");
            const after = Array.from(article.querySelectorAll("p"))
              .find((node) => node.textContent.trim() === "After");
            const image = article.querySelector("img");
            const table = article.querySelector(".table-scroll");
            const code = article.querySelector(".code-card");
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(before);
            range.collapse(false);
            selection.removeAllRanges();
            selection.addRange(range);

            const press = (key) => {
              const event = new KeyboardEvent("keydown", {
                key,
                bubbles: true,
                cancelable: true,
              });
              article.dispatchEvent(event);
              return event.defaultPrevented;
            };
            const selected = () =>
              article.querySelector(".editor-selected-object");
            const caretInside = (node) =>
              selection.rangeCount > 0 &&
              node.contains(selection.getRangeAt(0).startContainer);

            const states = [];
            states.push({
              prevented: press("ArrowDown"),
              target: selected() === image ? "image" : "other",
            });
            states.push({
              prevented: press("ArrowDown"),
              target: selected() === table ? "table" : "other",
            });
            states.push({
              prevented: press("ArrowDown"),
              target: selected() === code ? "code" : "other",
            });
            states.push({
              prevented: press("ArrowDown"),
              target: caretInside(after) ? "after" : "other",
            });
            states.push({
              prevented: press("ArrowUp"),
              target: selected() === code ? "code" : "other",
            });
            states.push({
              prevented: press("ArrowUp"),
              target: selected() === table ? "table" : "other",
            });
            states.push({
              prevented: press("ArrowUp"),
              target: selected() === image ? "image" : "other",
            });
            states.push({
              prevented: press("ArrowUp"),
              target: caretInside(before) ? "before" : "other",
            });
            return states;
            """,
            contentWorld: .page
        )
        let states = try XCTUnwrap(result as? [[String: Any]])

        XCTAssertEqual(
            states.compactMap { $0["target"] as? String },
            ["image", "table", "code", "after", "code", "table", "image", "before"]
        )
        XCTAssertTrue(states.allSatisfy { $0["prevented"] as? Bool == true })
    }

    func testHorizontalArrowsPlaceCaretBesideInlineObject() async throws {
        let webView = try await makeEditor(
            markdown: "Before ![icon](file:///tmp/AppIcon.svg) after.\n"
        )
        let result = try await webView.callAsyncJavaScript(
            """
            const article = document.querySelector("#preview-document");
            const image = article.querySelector("img");
            image.click();
            const right = new KeyboardEvent("keydown", {
              key: "ArrowRight",
              bubbles: true,
              cancelable: true,
            });
            article.dispatchEvent(right);
            const selection = window.getSelection();
            const range = selection.getRangeAt(0);
            return {
              prevented: right.defaultPrevented,
              collapsed: selection.isCollapsed,
              parentIsParagraph:
                range.startContainer === image.parentNode ||
                image.parentNode.contains(range.startContainer),
              offsetAfterImage:
                range.startContainer === image.parentNode &&
                range.startOffset ===
                  Array.from(image.parentNode.childNodes).indexOf(image) + 1,
              objectSelected:
                image.classList.contains("editor-selected-object"),
            };
            """,
            contentWorld: .page
        )
        let response = try XCTUnwrap(result as? [String: Any])

        XCTAssertEqual(response["prevented"] as? Bool, true)
        XCTAssertEqual(response["collapsed"] as? Bool, true)
        XCTAssertEqual(response["parentIsParagraph"] as? Bool, true)
        XCTAssertEqual(response["offsetAfterImage"] as? Bool, true)
        XCTAssertEqual(response["objectSelected"] as? Bool, false)
    }

    func testVerticalArrowsMoveBetweenTableRowsInTheSameColumn() async throws {
        let markdown = """
        Before

        | Name | Value |
        | --- | --- |
        | Alpha | 1 |

        After
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            """
            const article = document.querySelector("#preview-document");
            const table = article.querySelector("table");
            const header = table.rows[0].cells[0];
            const body = table.rows[1].cells[0];
            const after = Array.from(article.querySelectorAll("p"))
              .find((node) => node.textContent.trim() === "After");
            const selection = window.getSelection();
            const range = document.createRange();
            range.setStart(header.firstChild, 3);
            range.collapse(true);
            selection.removeAllRanges();
            selection.addRange(range);

            const press = (key) => {
              const event = new KeyboardEvent("keydown", {
                key,
                bubbles: true,
                cancelable: true,
              });
              article.dispatchEvent(event);
              return event.defaultPrevented;
            };
            const caret = () => {
              const current = selection.getRangeAt(0);
              return {
                container: current.startContainer,
                offset: current.startOffset,
              };
            };

            const downPrevented = press("ArrowDown");
            const downCaret = caret();
            const downInsideBody = body.contains(downCaret.container);
            const downOffset = downCaret.offset;
            const selectedBody =
              article.querySelector(".editor-selected-object") === body;

            const upPrevented = press("ArrowUp");
            const upCaret = caret();
            const upInsideHeader = header.contains(upCaret.container);
            const upOffset = upCaret.offset;

            press("ArrowDown");
            const exitPrevented = press("ArrowDown");
            const exitCaret = caret();
            return {
              downPrevented,
              downInsideBody,
              downOffset,
              selectedBody,
              upPrevented,
              upInsideHeader,
              upOffset,
              exitPrevented,
              exitedToAfter: after.contains(exitCaret.container),
            };
            """,
            contentWorld: .page
        )
        let response = try XCTUnwrap(result as? [String: Any])

        XCTAssertEqual(response["downPrevented"] as? Bool, true)
        XCTAssertEqual(response["downInsideBody"] as? Bool, true)
        XCTAssertEqual(response["downOffset"] as? Int, 3)
        XCTAssertEqual(response["selectedBody"] as? Bool, true)
        XCTAssertEqual(response["upPrevented"] as? Bool, true)
        XCTAssertEqual(response["upInsideHeader"] as? Bool, true)
        XCTAssertEqual(response["upOffset"] as? Int, 3)
        XCTAssertEqual(response["exitPrevented"] as? Bool, true)
        XCTAssertEqual(response["exitedToAfter"] as? Bool, true)
    }

    func testVerticalArrowsMoveOneListItemAtATime() async throws {
        let markdown = """
        Before

        - Alpha
        - Bravo
        - Parent
          - Nested
        - [ ] Todo

        After
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            """
            const article = document.querySelector("#preview-document");
            const before = Array.from(article.querySelectorAll("p"))
              .find((node) => node.textContent.trim() === "Before");
            const after = Array.from(article.querySelectorAll("p"))
              .find((node) => node.textContent.trim() === "After");
            const items = Array.from(article.querySelectorAll("li"));
            const selection = window.getSelection();
            const range = document.createRange();
            range.setStart(before.firstChild, 2);
            range.collapse(true);
            selection.removeAllRanges();
            selection.addRange(range);

            const press = (key) => {
              const event = new KeyboardEvent("keydown", {
                key,
                bubbles: true,
                cancelable: true,
              });
              article.dispatchEvent(event);
              return event.defaultPrevented;
            };
            const caretState = () => {
              const current = selection.getRangeAt(0);
              const anchor =
                current.startContainer.nodeType === Node.ELEMENT_NODE
                  ? current.startContainer
                  : current.startContainer.parentElement;
              const item = anchor && anchor.closest("li");
              const ownText = item ? item.cloneNode(true) : null;
              if (ownText) {
                ownText
                  .querySelectorAll("ul, ol, input")
                  .forEach((node) => node.remove());
              }
              return {
                label: item
                  ? ownText.textContent.trim()
                  : after.contains(current.startContainer)
                    ? "After"
                    : "Other",
                offset: current.startOffset,
              };
            };

            const states = [];
            for (let index = 0; index < items.length; index += 1) {
              states.push({
                prevented: press("ArrowDown"),
                ...caretState(),
              });
            }
            states.push({
              prevented: press("ArrowDown"),
              ...caretState(),
            });
            for (let index = 0; index < items.length; index += 1) {
              states.push({
                prevented: press("ArrowUp"),
                ...caretState(),
              });
            }
            return states;
            """,
            contentWorld: .page
        )
        let states = try XCTUnwrap(result as? [[String: Any]])

        XCTAssertEqual(
            states.compactMap { $0["label"] as? String },
            [
                "Alpha",
                "Bravo",
                "Parent",
                "Nested",
                "Todo",
                "After",
                "Todo",
                "Nested",
                "Parent",
                "Bravo",
                "Alpha",
            ]
        )
        XCTAssertTrue(states.allSatisfy { $0["prevented"] as? Bool == true })
        XCTAssertTrue(
            states
                .filter { ($0["label"] as? String) != "After" }
                .allSatisfy { $0["offset"] as? Int == 2 }
        )
    }

    func testVerticalArrowWithinMultilineListItemRemainsNative() async throws {
        let markdown = """
        - First line\u{20}\u{20}
          Second line
        - Next item
        """
        let webView = try await makeEditor(markdown: markdown)
        let result = try await webView.callAsyncJavaScript(
            """
            const article = document.querySelector("#preview-document");
            const firstItem = article.querySelector("li");
            const textNode = Array.from(firstItem.childNodes)
              .find((node) => node.nodeType === Node.TEXT_NODE);
            const selection = window.getSelection();
            const range = document.createRange();
            range.setStart(textNode, 3);
            range.collapse(true);
            selection.removeAllRanges();
            selection.addRange(range);

            const event = new KeyboardEvent("keydown", {
              key: "ArrowDown",
              bubbles: true,
              cancelable: true,
            });
            article.dispatchEvent(event);
            return event.defaultPrevented;
            """,
            contentWorld: .page
        )

        XCTAssertEqual(result as? Bool, false)
    }

    func testInserterProducesMarkdownForEveryBuiltInBlock() async throws {
        let webView = try await makeEditor(markdown: "")
        let result = try await webView.callAsyncJavaScript(
            """
            const baseOptions = {
              documentID: "inserter-test",
              markdown: "",
              revision: 0,
              editable: true,
              theme: "light",
              readingStyle: "modern",
              systemDark: false,
              readingWidth: 820,
              paperCanvas: false,
              zoom: 1,
              searchText: "",
              outlineTarget: null,
              topInset: 0,
            };
            const actions = [
              "heading-1", "heading-2", "heading-3", "heading-4",
              "heading-5", "heading-6", "quote", "bullet-list",
              "numbered-list", "task-list", "table", "code", "mermaid",
              "image", "image-url", "link", "math", "divider", "alert-note",
              "alert-tip", "alert-important", "alert-warning",
              "alert-caution", "footnote",
            ];
            const promptValues = {
              image: ["images/photo.png", "Photo", "Title"],
              "image-url": ["https://example.com/photo.png", "Remote photo", ""],
              link: ["Guide", "guide.md"],
              math: ["x^2 + y^2"],
              footnote: ["details", "Footnote text."],
            };
            const output = {};

            for (const action of actions) {
              await window.previewmdRender(baseOptions);
              const paragraph = document.querySelector("#preview-document p");
              const range = document.createRange();
              range.selectNodeContents(paragraph);
              range.collapse(true);
              const selection = window.getSelection();
              selection.removeAllRanges();
              selection.addRange(range);

              const answers = (promptValues[action] || []).slice();
              window.prompt = () => answers.shift() ?? null;
              output[action] = window.previewmdInsertBlock(action);
            }
            return output;
            """,
            contentWorld: .page
        )
        let output = try XCTUnwrap(result as? [String: String])

        XCTAssertEqual(output["heading-1"], "# Heading 1\n")
        XCTAssertEqual(output["heading-6"], "###### Heading 6\n")
        XCTAssertEqual(output["quote"], "> Quote\n")
        XCTAssertEqual(output["bullet-list"], "- List item\n")
        XCTAssertEqual(output["numbered-list"], "1. List item\n")
        XCTAssertEqual(output["task-list"], "- [ ] Task\n")
        XCTAssertTrue(try XCTUnwrap(output["table"]).contains("| Column 1 | Column 2 | Column 3 |"))
        XCTAssertEqual(output["code"], "```\n\n```\n")
        XCTAssertTrue(try XCTUnwrap(output["mermaid"]).contains("```mermaid\nflowchart LR"))
        XCTAssertEqual(output["image"], "![Photo](images/photo.png \"Title\")\n")
        XCTAssertEqual(
            output["image-url"],
            "![Remote photo](https://example.com/photo.png)\n"
        )
        XCTAssertEqual(output["link"], "[Guide](guide.md)\n")
        XCTAssertEqual(output["math"], "$$\nx^2 + y^2\n$$\n")
        XCTAssertEqual(output["divider"], "---\n")
        XCTAssertEqual(output["alert-note"], "> [!NOTE]\n> Note\n")
        XCTAssertEqual(output["alert-tip"], "> [!TIP]\n> Tip\n")
        XCTAssertEqual(output["alert-important"], "> [!IMPORTANT]\n> Important\n")
        XCTAssertEqual(output["alert-warning"], "> [!WARNING]\n> Warning\n")
        XCTAssertEqual(output["alert-caution"], "> [!CAUTION]\n> Caution\n")
        XCTAssertEqual(
            output["footnote"],
            "Reference[^details]\n\n[^details]: Footnote text.\n"
        )
    }

    func testRawMarkdownComposerInsertsArbitraryMultilineBlock() async throws {
        let webView = try await makeEditor(markdown: "")
        let result = try await webView.callAsyncJavaScript(
            """
            const paragraph = document.querySelector("#preview-document p");
            const range = document.createRange();
            range.selectNodeContents(paragraph);
            range.collapse(true);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);

            window.previewmdInsertBlock("raw-markdown");
            const composer = document.querySelector(".editor-markdown-composer");
            composer.querySelector("textarea").value =
              "## Custom block\\n\\n<details>\\n<summary>More</summary>\\nBody\\n</details>";
            composer.querySelector("[data-composer-apply]").click();
            return window.previewmdFlushEditor();
            """,
            contentWorld: .page
        )

        XCTAssertEqual(
            result as? String,
            "## Custom block\n\n<details>\n<summary>More</summary>\nBody\n</details>\n"
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        navigationExpectation?.fulfill()
    }

    private func makeEditor(markdown: String) async throws -> WKWebView {
        let payload = MarkdownWebView.RenderPayload(
            documentID: UUID().uuidString,
            markdown: markdown,
            revision: 0,
            editable: true,
            theme: PreviewTheme.light.rawValue,
            readingStyle: ReadingStyle.modern.rawValue,
            systemDark: false,
            readingWidth: 820,
            paperCanvas: false,
            zoom: 1,
            searchText: "",
            outlineTarget: nil,
            topInset: 0
        )
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
        webView.navigationDelegate = self

        let loaded = expectation(description: "Renderer shell loaded")
        navigationExpectation = loaded
        webView.loadHTMLString(
            RendererAssets.shellHTML(for: payload),
            baseURL: Bundle.module.resourceURL
        )
        await fulfillment(of: [loaded], timeout: 5)
        navigationExpectation = nil

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        _ = try await webView.callAsyncJavaScript(
            """
            await window.previewmdRender(options);
            return window.previewmdSerializeEditor();
            """,
            arguments: ["options": object],
            contentWorld: .page
        )
        return webView
    }
}
#endif
