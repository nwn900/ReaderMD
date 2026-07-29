import AppKit
import Foundation
import SwiftUI
import WebKit

@MainActor
final class RendererController: ObservableObject {
    private weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func exportPDF(
        suggestedName: String,
        completion: @escaping ((any Error)?) -> Void
    ) {
        guard let webView else {
            completion(RendererError.rendererUnavailable)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export PDF"
        panel.prompt = "Export"
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        let configuration = WKPDFConfiguration()
        webView.createPDF(configuration: configuration) { result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: destinationURL, options: .atomic)
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    private enum RendererError: LocalizedError {
        case rendererUnavailable

        var errorDescription: String? {
            "The preview renderer is not available."
        }
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let documentURL: URL?
    let theme: PreviewTheme
    let readingStyle: ReadingStyle
    let readingWidth: Int
    let usesPaperCanvas: Bool
    let zoom: Double
    let searchText: String
    let outlineTarget: String?
    let topInset: Double
    let controller: RendererController
    let onDropFiles: ([URL]) -> Void
    let onDropTargeted: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var state: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(openMarkdown: state.open(url:))
    }

    private var renderPayload: RenderPayload {
        RenderPayload(
            markdown: markdown,
            theme: theme.rawValue,
            readingStyle: readingStyle.rawValue,
            systemDark: colorScheme == .dark,
            readingWidth: readingWidth,
            paperCanvas: usesPaperCanvas,
            zoom: zoom,
            searchText: searchText,
            outlineTarget: outlineTarget,
            topInset: topInset
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.userContentController.add(context.coordinator, name: "copyText")

        let webView = MarkdownDropWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.underPageBackgroundColor = .clear
        webView.onDropFiles = onDropFiles
        webView.onDropTargeted = onDropTargeted
        context.coordinator.webView = webView
        controller.attach(webView)
        let initialPayload = renderPayload
        webView.pageZoom = initialPayload.zoom
        context.coordinator.loadShell(
            baseURL: baseURL,
            initialPayload: initialPayload,
            in: webView
        )
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        controller.attach(webView)
        context.coordinator.openMarkdown = state.open(url:)
        if let dropWebView = webView as? MarkdownDropWebView {
            dropWebView.onDropFiles = onDropFiles
            dropWebView.onDropTargeted = onDropTargeted
        }

        let payload = renderPayload
        let newBasePath = baseURL.path
        if context.coordinator.basePath != newBasePath {
            context.coordinator.loadShell(
                baseURL: baseURL,
                initialPayload: payload,
                in: webView
            )
        } else {
            context.coordinator.update(payload, in: webView)
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "copyText")
        webView.navigationDelegate = nil
        if let dropWebView = webView as? MarkdownDropWebView {
            dropWebView.onDropFiles = nil
            dropWebView.onDropTargeted = nil
        }
    }

    private var baseURL: URL {
        documentURL?.deletingLastPathComponent()
            ?? Bundle.module.resourceURL
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    struct RenderPayload: Codable, Equatable {
        let markdown: String
        let theme: String
        let readingStyle: String
        let systemDark: Bool
        let readingWidth: Int
        let paperCanvas: Bool
        let zoom: Double
        let searchText: String
        let outlineTarget: String?
        /// Height of the window toolbar the page has to clear in focus mode,
        /// where the web view extends underneath it. Layout-only, so it travels
        /// through `previewmdSetLayout` and never forces a re-render.
        let topInset: Double

        func requiresFullRender(comparedTo other: Self) -> Bool {
            markdown != other.markdown
                || theme != other.theme
                || readingStyle != other.readingStyle
                || systemDark != other.systemDark
        }

        var initialTheme: String {
            if theme == PreviewTheme.dark.rawValue
                || (theme == PreviewTheme.system.rawValue && systemDark) {
                return PreviewTheme.dark.rawValue
            }
            return PreviewTheme.light.rawValue
        }

        var rootHTMLAttributes: String {
            let paperValue = paperCanvas ? "true" : "false"
            return """
            data-theme="\(initialTheme)" data-style="\(readingStyle)" data-paper="\(paperValue)" \
            style="--reading-width: \(readingWidth)px; --top-inset: \(topInset)px"
            """
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var openMarkdown: (URL) -> Void
        var basePath = ""

        private var isLoaded = false
        private var pendingPayload: RenderPayload?
        private var lastPayload: RenderPayload?

        init(openMarkdown: @escaping (URL) -> Void) {
            self.openMarkdown = openMarkdown
        }

        func loadShell(
            baseURL: URL,
            initialPayload: RenderPayload,
            in webView: WKWebView
        ) {
            basePath = baseURL.path
            isLoaded = false
            lastPayload = nil
            pendingPayload = initialPayload
            webView.pageZoom = initialPayload.zoom
            webView.loadHTMLString(
                RendererAssets.shellHTML(for: initialPayload),
                baseURL: baseURL
            )
        }

        func update(_ payload: RenderPayload, in webView: WKWebView) {
            guard payload != lastPayload else { return }
            pendingPayload = payload
            guard isLoaded else { return }
            applyPendingPayload(in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            isLoaded = true
            applyPendingPayload(in: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            if MarkdownFileSupport.accepts(url) {
                openMarkdown(url)
                decisionHandler(.cancel)
                return
            }

            if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            MainActor.assumeIsolated {
                guard message.name == "copyText", let text = message.body as? String else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }

        private func applyPendingPayload(in webView: WKWebView) {
            guard let payload = pendingPayload else { return }

            pendingPayload = nil
            webView.pageZoom = payload.zoom

            if let previous = lastPayload,
               !payload.requiresFullRender(comparedTo: previous) {
                lastPayload = payload

                if payload.readingWidth != previous.readingWidth
                    || payload.paperCanvas != previous.paperCanvas
                    || payload.topInset != previous.topInset {
                    webView.evaluateJavaScript(
                        "window.previewmdSetLayout(\(payload.readingWidth), \(payload.paperCanvas), \(payload.topInset));"
                    )
                }

                if payload.searchText != previous.searchText,
                   let searchJSON = javaScriptJSON(payload.searchText) {
                    webView.evaluateJavaScript("window.previewmdFind(\(searchJSON));")
                }

                if let target = payload.outlineTarget,
                   target != previous.outlineTarget,
                   let targetJSON = javaScriptJSON(target) {
                    webView.evaluateJavaScript("window.previewmdScrollTo(\(targetJSON));")
                }
                return
            }

            guard let data = try? JSONEncoder().encode(payload),
                  let json = String(data: data, encoding: .utf8)
            else { return }

            lastPayload = payload
            webView.evaluateJavaScript("window.previewmdRender(\(json));")
        }

        private func javaScriptJSON<T: Encodable>(_ value: T) -> String? {
            guard let data = try? JSONEncoder().encode(value) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
}

@MainActor
private final class MarkdownDropWebView: WKWebView {
    var onDropFiles: (([URL]) -> Void)?
    var onDropTargeted: ((Bool) -> Void)?

    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !supportedURLs(from: sender).isEmpty else {
            onDropTargeted?(false)
            return super.draggingEntered(sender)
        }
        onDropTargeted?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !supportedURLs(from: sender).isEmpty else {
            onDropTargeted?(false)
            return super.draggingUpdated(sender)
        }
        onDropTargeted?(true)
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDropTargeted?(false)
        super.draggingExited(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = supportedURLs(from: sender)
        guard !urls.isEmpty else {
            onDropTargeted?(false)
            return super.performDragOperation(sender)
        }

        onDropTargeted?(false)
        onDropFiles?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        onDropTargeted?(false)
        super.concludeDragOperation(sender)
    }

    private func supportedURLs(from draggingInfo: any NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) ?? []

        return objects
            .compactMap { ($0 as? NSURL) as URL? }
            .filter(MarkdownFileSupport.accepts)
    }
}

enum RendererAssets {
    private static let markdownIt = script(named: "markdown-it.min")
    private static let footnotes = script(named: "markdown-it-footnote.min")
    private static let highlight = script(named: "highlight.min")
    private static let katex = script(named: "katex.min")
    private static let autoRender = script(named: "auto-render.min")
    private static let mermaid = script(named: "mermaid.min")
    private static let renderer = script(named: "renderer")
    private static let baseCSS = text(named: "renderer", extension: "css")
    private static let katexCSS = rewrittenKaTeXCSS()

    static func shellHTML(for initialPayload: MarkdownWebView.RenderPayload) -> String {
        return """
        <!doctype html>
        <html lang="en" \(initialPayload.rootHTMLAttributes)>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <style>\(katexCSS)</style>
          <style>\(baseCSS)</style>
        </head>
        <body>
          <div id="reading-progress"></div>
          <main id="preview-shell" aria-live="polite">
            <article id="preview-document"></article>
          </main>
          <div id="render-error" hidden></div>
          <script>\(markdownIt)</script>
          <script>\(footnotes)</script>
          <script>\(highlight)</script>
          <script>\(katex)</script>
          <script>\(autoRender)</script>
          <script>\(mermaid)</script>
          <script>\(renderer)</script>
        </body>
        </html>
        """
    }

    private static func script(named name: String) -> String {
        text(named: name, extension: "js")
            .replacingOccurrences(of: "</script>", with: "<\\/script>")
    }

    private static func text(named name: String, extension fileExtension: String) -> String {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Renderer"
        ) else {
            return ""
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private static func rewrittenKaTeXCSS() -> String {
        let css = text(named: "katex.min", extension: "css")
        guard let fontsURL = Bundle.module.url(
            forResource: "fonts",
            withExtension: nil,
            subdirectory: "Renderer"
        ) else {
            return css
        }
        let prefix = fontsURL.absoluteString
        return css.replacingOccurrences(of: "url(fonts/", with: "url(\(prefix)/")
    }
}
