import Foundation
import UniformTypeIdentifiers
import WebKit

/// Loads local Markdown images in the app process.
///
/// `WKWebView.loadHTMLString` resolves relative file URLs, but WebKit's content
/// process is not granted access to ordinary user folders. Routing only image
/// requests through a custom scheme keeps the renderer offline without giving
/// the web process broad filesystem access.
final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    nonisolated static let scheme = "previewmd-local-image"
    nonisolated static let maximumFileSize = 100 * 1_024 * 1_024

    private var baseURL: URL
    private var loadTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(baseURL: URL) {
        self.baseURL = baseURL.standardizedFileURL
    }

    func updateBaseURL(_ baseURL: URL) {
        self.baseURL = baseURL.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let identifier = ObjectIdentifier(urlSchemeTask)
        let requestURL = urlSchemeTask.request.url
        let baseURL = baseURL
        loadTasks[identifier] = Task { [weak self] in
            do {
                let resource = try await Task.detached(priority: .userInitiated) {
                    try Self.resource(for: requestURL, relativeTo: baseURL)
                }.value
                try Task.checkCancellation()
                guard let self,
                      self.loadTasks.removeValue(forKey: identifier) != nil
                else { return }

                let response = URLResponse(
                    url: requestURL ?? resource.fileURL,
                    mimeType: resource.mimeType,
                    expectedContentLength: resource.data.count,
                    textEncodingName: nil
                )
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(resource.data)
                urlSchemeTask.didFinish()
            } catch is CancellationError {
                self?.loadTasks.removeValue(forKey: identifier)
            } catch {
                guard let self,
                      self.loadTasks.removeValue(forKey: identifier) != nil
                else { return }
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        let identifier = ObjectIdentifier(urlSchemeTask)
        loadTasks.removeValue(forKey: identifier)?.cancel()
    }

    nonisolated static func resource(
        for requestURL: URL?,
        relativeTo baseURL: URL
    ) throws -> Resource {
        let fileURL = try fileURL(for: requestURL, relativeTo: baseURL)
        let resourceValues = try fileURL.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey]
        )
        guard resourceValues.isRegularFile == true else {
            throw LoadError.notRegularFile
        }
        guard let fileSize = resourceValues.fileSize,
              fileSize <= maximumFileSize
        else {
            throw LoadError.fileTooLarge
        }
        guard let type = UTType(filenameExtension: fileURL.pathExtension),
              type.conforms(to: .image),
              let mimeType = type.preferredMIMEType
        else {
            throw LoadError.unsupportedType
        }

        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        guard data.count <= maximumFileSize else {
            throw LoadError.fileTooLarge
        }
        return Resource(fileURL: fileURL, mimeType: mimeType, data: data)
    }

    nonisolated static func fileURL(
        for requestURL: URL?,
        relativeTo baseURL: URL
    ) throws -> URL {
        let directoryBaseURL = URL(
            fileURLWithPath: baseURL.standardizedFileURL.path,
            isDirectory: true
        )
        guard let requestURL,
              requestURL.scheme?.lowercased() == scheme,
              requestURL.host == "resource",
              let components = URLComponents(
                  url: requestURL,
                  resolvingAgainstBaseURL: false
              ),
              let source = components.queryItems?.first(where: { $0.name == "source" })?.value,
              !source.isEmpty,
              let resolvedURL = URL(
                  string: source,
                  relativeTo: directoryBaseURL
              )?.absoluteURL,
              resolvedURL.isFileURL
        else {
            throw LoadError.invalidRequest
        }

        let host = resolvedURL.host?.lowercased()
        guard host == nil || host == "" || host == "localhost" else {
            throw LoadError.invalidRequest
        }
        return resolvedURL.standardizedFileURL
    }

    struct Resource: Sendable {
        let fileURL: URL
        let mimeType: String
        let data: Data
    }

    enum LoadError: LocalizedError, Equatable, Sendable {
        case invalidRequest
        case notRegularFile
        case unsupportedType
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .invalidRequest:
                "The local image request is invalid."
            case .notRegularFile:
                "The local image is not a regular file."
            case .unsupportedType:
                "The local file is not a supported image."
            case .fileTooLarge:
                "The local image is too large to display."
            }
        }
    }
}
