import AppKit
import Foundation
import Quartz
import WebKit

@MainActor
final class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView!
    private var navigationWaiter: CheckedContinuation<Void, any Error>?
    private var securityScopedURL: URL?

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = .clear
        self.webView = webView
        view = webView
        preferredContentSize = NSSize(width: 900, height: 700)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        _ = view
        stopAccessingCurrentFile()
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }

        do {
            let markdown = try Self.readMarkdown(from: url)
            let usesDarkAppearance = view.effectiveAppearance.bestMatch(
                from: [.darkAqua, .aqua]
            ) == .darkAqua
            let html = try QuickLookRenderer.shellHTML(
                markdown: markdown,
                usesDarkAppearance: usesDarkAppearance
            )

            try await withCheckedThrowingContinuation { continuation in
                navigationWaiter?.resume(throwing: CancellationError())
                navigationWaiter = continuation
                webView.loadHTMLString(
                    html,
                    baseURL: url.deletingLastPathComponent()
                )
            }
        } catch {
            stopAccessingCurrentFile()
            throw error
        }
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    private func stopAccessingCurrentFile() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    static func readMarkdown(from url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let textData = data.starts(with: [0xEF, 0xBB, 0xBF])
            ? data.dropFirst(3)
            : data[...]
        guard let decoded = String(data: textData, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return decoded
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

extension PreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationWaiter?.resume()
        navigationWaiter = nil
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        finishNavigation(with: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        finishNavigation(with: error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finishNavigation(with: QuickLookRenderer.Error.webContentProcessTerminated)
    }

    private func finishNavigation(with error: any Error) {
        navigationWaiter?.resume(throwing: error)
        navigationWaiter = nil
    }
}

enum QuickLookRenderer {
    enum Error: LocalizedError {
        case missingResource(String)
        case invalidPayload
        case webContentProcessTerminated

        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                "ReaderMD Quick Look is missing the renderer resource \(name)."
            case .invalidPayload:
                "ReaderMD couldn’t prepare the Markdown preview."
            case .webContentProcessTerminated:
                "The Markdown preview process stopped unexpectedly."
            }
        }
    }

    private static let scripts = [
        "markdown-it.min",
        "markdown-it-footnote.min",
        "highlight.min",
        "katex.min",
        "auto-render.min",
        "mermaid.min",
        "renderer",
    ]

    static func shellHTML(markdown: String, usesDarkAppearance: Bool) throws -> String {
        let css = try text(named: "renderer", extension: "css")
        let katexCSS = try rewrittenKaTeXCSS()
        let embeddedScripts = try scripts.map { name in
            let script = try text(named: name, extension: "js")
                .replacingOccurrences(of: "</script>", with: "<\\/script>")
            return "<script>\(script)</script>"
        }.joined(separator: "\n")
        let payload = try payloadJSON(
            markdown: markdown,
            usesDarkAppearance: usesDarkAppearance
        )
        let theme = usesDarkAppearance ? "dark" : "light"

        return """
        <!doctype html>
        <html lang="en" data-theme="\(theme)" data-style="modern" data-paper="false"
              style="--reading-width: 880px; --top-inset: 0px">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <meta http-equiv="Content-Security-Policy"
                content="default-src 'none'; img-src file: data: blob:; font-src file: data:; style-src 'unsafe-inline' file:; script-src 'unsafe-inline'; connect-src 'none'; media-src file: data:">
          <style>\(katexCSS)</style>
          <style>\(css)</style>
          <style>
            .quicklook-image-placeholder {
              display: grid;
              place-items: center;
              min-height: 96px;
              margin: 1.25em 0;
              padding: 18px;
              color: var(--muted, #6e6e73);
              font-size: 0.9em;
              text-align: center;
              border: 1px dashed color-mix(in srgb, currentColor 35%, transparent);
              border-radius: 12px;
              background: color-mix(in srgb, currentColor 4%, transparent);
            }
          </style>
        </head>
        <body>
          <div id="reading-progress"></div>
          <div id="top-blur" aria-hidden="true"></div>
          <main id="preview-shell" aria-live="polite">
            <article id="preview-document"></article>
          </main>
          <div id="render-error" hidden></div>
          \(embeddedScripts)
          <script>
          (function () {
            const article = document.getElementById("preview-document");
            article.addEventListener("error", function (event) {
              const image = event.target;
              if (!(image instanceof HTMLImageElement)) return;
              const placeholder = document.createElement("div");
              placeholder.className = "quicklook-image-placeholder";
              const label = image.alt ? "“" + image.alt + "” — " : "";
              placeholder.textContent =
                label + "local image is available after opening the document in ReaderMD";
              image.replaceWith(placeholder);
            }, true);
            window.readermdRender(\(payload));
          })();
          </script>
        </body>
        </html>
        """
    }

    static func payloadJSON(
        markdown: String,
        usesDarkAppearance: Bool
    ) throws -> String {
        let payload: [String: Any] = [
            "documentID": "quick-look",
            "markdown": markdown,
            "revision": 0,
            "editable": false,
            "theme": "system",
            "readingStyle": "modern",
            "systemDark": usesDarkAppearance,
            "readingWidth": 880,
            "paperCanvas": false,
            "zoom": 1.0,
            "searchText": "",
            "topInset": 0,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw Error.invalidPayload
        }
        return json
            .replacingOccurrences(of: "<", with: "\\u003C")
            .replacingOccurrences(of: ">", with: "\\u003E")
            .replacingOccurrences(of: "&", with: "\\u0026")
    }

    private static func text(named name: String, extension fileExtension: String) throws -> String {
        let bundle = Bundle(for: PreviewViewController.self)
        guard let url = bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Renderer"
        ) else {
            throw Error.missingResource("\(name).\(fileExtension)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func rewrittenKaTeXCSS() throws -> String {
        let css = try text(named: "katex.min", extension: "css")
        let bundle = Bundle(for: PreviewViewController.self)
        guard let fontsURL = bundle.url(
            forResource: "fonts",
            withExtension: nil,
            subdirectory: "Renderer"
        ) else {
            throw Error.missingResource("Renderer/fonts")
        }
        return css.replacingOccurrences(
            of: "url(fonts/",
            with: "url(\(fontsURL.absoluteString)/"
        )
    }
}
