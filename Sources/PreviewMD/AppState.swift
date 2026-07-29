import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var documents: [MarkdownDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var recentDocuments: [RecentDocument] = []
    @Published var displayMode: DisplayMode = .preview
    @Published var theme: PreviewTheme = .system
    @Published var readingStyle: ReadingStyle = .modern
    @Published var readingWidth: ReadingWidth = .comfortable
    @Published var customReadingWidth: Double = 820
    @Published var usesPaperCanvas = false
    @Published var isInspectorVisible = false
    /// Distraction-free reading: every piece of chrome is hidden except the
    /// document column and the reading-width ruler. Deliberately not persisted —
    /// it is a thing you do to a session, not a preference.
    @Published private(set) var isFocusMode = false
    @Published var searchText = ""
    @Published var zoom: Double = 1
    @Published var outlineTarget: String?
    @Published var searchFieldFocusToken = UUID()
    @Published var sidebarSelection = ""
    @Published var errorMessage: String?

    let rendererController = RendererController()

    private let defaults: UserDefaults
    private let recentKey = "recentDocuments.v1"
    private let themeKey = "previewTheme"
    private let styleKey = "readingStyle"
    private let widthKey = "readingWidth"
    private let customWidthKey = "customReadingWidth"
    private let paperKey = "usesPaperCanvas"

    /// Restored when focus mode ends, so entering it to read does not quietly
    /// throw away the split or source view you were working in.
    private var displayModeBeforeFocus: DisplayMode?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadPreferences()
        loadRecentDocuments()
    }

    var currentDocumentIndex: Int? {
        guard let selectedDocumentID else { return nil }
        return documents.firstIndex { $0.id == selectedDocumentID }
    }

    var currentDocument: MarkdownDocument? {
        guard let currentDocumentIndex else { return nil }
        return documents[currentDocumentIndex]
    }

    var currentOutline: [OutlineHeading] {
        guard let currentDocument else { return [] }
        return MarkdownOutline.headings(in: currentDocument.content)
    }

    var effectiveReadingWidth: Int {
        if readingWidth == .custom {
            return Int(customReadingWidth.rounded())
        }
        return readingWidth.cssValue
    }

    func bindingForCurrentContent() -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.currentDocument?.content ?? ""
            },
            set: { [weak self] newValue in
                guard let self, let index = self.currentDocumentIndex else { return }
                self.documents[index].content = newValue
            }
        )
    }

    func openWelcome() {
        if let existing = documents.first(where: { $0.isSample }) {
            selectedDocumentID = existing.id
            sidebarSelection = "welcome"
            return
        }

        let content = ShowcaseDocument.markdown
        let document = MarkdownDocument(
            id: UUID(),
            url: nil,
            title: "Welcome to PreviewMD",
            content: content,
            lastSavedContent: content,
            openedAt: Date(),
            fileModifiedAt: nil,
            isPinned: true,
            isSample: true
        )
        documents.insert(document, at: 0)
        selectedDocumentID = document.id
        sidebarSelection = "welcome"
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown"
        panel.prompt = "Open"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = Self.markdownContentTypes
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            panel.urls.forEach { self?.open(url: $0) }
        }
    }

    func open(url: URL) {
        guard url.isFileURL else {
            NSWorkspace.shared.open(url)
            return
        }

        let normalizedURL = url.standardizedFileURL
        if let existing = documents.first(where: { $0.url?.standardizedFileURL == normalizedURL }) {
            selectedDocumentID = existing.id
            sidebarSelection = normalizedURL.path
            touchRecent(normalizedURL)
            return
        }

        do {
            let content = try String(contentsOf: normalizedURL, encoding: .utf8)
            let values = try? normalizedURL.resourceValues(forKeys: [.contentModificationDateKey])
            let recent = recentDocuments.first { $0.path == normalizedURL.path }
            let document = MarkdownDocument(
                id: UUID(),
                url: normalizedURL,
                title: normalizedURL.deletingPathExtension().lastPathComponent,
                content: content,
                lastSavedContent: content,
                openedAt: Date(),
                fileModifiedAt: values?.contentModificationDate,
                isPinned: recent?.isPinned ?? false,
                isSample: false
            )
            documents.append(document)
            selectedDocumentID = document.id
            sidebarSelection = normalizedURL.path
            touchRecent(normalizedURL)
            searchText = ""
        } catch {
            present(error: "Couldn’t open “\(normalizedURL.lastPathComponent)”. \(error.localizedDescription)")
        }
    }

    func select(documentID: UUID) {
        selectedDocumentID = documentID
        if let document = documents.first(where: { $0.id == documentID }) {
            sidebarSelection = document.isSample ? "welcome" : (document.url?.path ?? "")
        }
        searchText = ""
    }

    func closeTab(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let document = documents[index]

        if document.isDirty {
            let alert = NSAlert()
            alert.messageText = "Save changes to “\(document.title)”?"
            alert.informativeText = "Your changes will be lost if you close this tab without saving."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Don’t Save")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                selectedDocumentID = id
                saveCurrent()
                guard currentDocument?.isDirty == false else { return }
            } else if response == .alertSecondButtonReturn {
                return
            }
        }

        documents.remove(at: index)

        if selectedDocumentID == id {
            if documents.indices.contains(index) {
                selectedDocumentID = documents[index].id
            } else {
                selectedDocumentID = documents.last?.id
            }
        }

        if documents.isEmpty {
            selectedDocumentID = nil
            sidebarSelection = ""
            searchText = ""
            outlineTarget = nil
            // Nothing left to read, and focus mode hides the chrome needed to
            // open something else.
            exitFocusMode()
        } else if let currentDocument {
            sidebarSelection = currentDocument.isSample
                ? "welcome"
                : (currentDocument.url?.path ?? "")
        }
    }

    func closeCurrentTab() {
        guard let selectedDocumentID else { return }
        closeTab(selectedDocumentID)
    }

    // MARK: - Focus mode

    var canEnterFocusMode: Bool {
        currentDocument != nil
    }

    func toggleFocusMode() {
        isFocusMode ? exitFocusMode() : enterFocusMode()
    }

    func enterFocusMode() {
        guard canEnterFocusMode, !isFocusMode else { return }
        // Focus mode is for reading, so it shows the preview. Remember the mode
        // being left behind rather than stranding the reader in it afterwards.
        displayModeBeforeFocus = displayMode
        displayMode = .preview
        isInspectorVisible = false
        searchText = ""
        isFocusMode = true
    }

    func exitFocusMode() {
        guard isFocusMode else { return }
        isFocusMode = false
        if let previous = displayModeBeforeFocus {
            displayMode = previous
            displayModeBeforeFocus = nil
        }
    }

    func saveCurrent() {
        guard let index = currentDocumentIndex else { return }
        if documents[index].url == nil || documents[index].isSample {
            saveCurrentAs()
            return
        }

        guard let url = documents[index].url else { return }
        do {
            try documents[index].content.write(to: url, atomically: true, encoding: .utf8)
            documents[index].lastSavedContent = documents[index].content
            documents[index].fileModifiedAt = Date()
            touchRecent(url)
        } catch {
            present(error: "Couldn’t save “\(documents[index].title)”. \(error.localizedDescription)")
        }
    }

    func saveCurrentAs() {
        guard let index = currentDocumentIndex else { return }
        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.prompt = "Save"
        panel.nameFieldStringValue = documents[index].isSample
            ? "PreviewMD Showcase.md"
            : "\(documents[index].title).md"
        panel.allowedContentTypes = Self.markdownContentTypes
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try documents[index].content.write(to: url, atomically: true, encoding: .utf8)
            documents[index].url = url
            documents[index].title = url.deletingPathExtension().lastPathComponent
            documents[index].lastSavedContent = documents[index].content
            documents[index].fileModifiedAt = Date()
            documents[index].isSample = false
            sidebarSelection = url.path
            touchRecent(url)
        } catch {
            present(error: "Couldn’t save “\(url.lastPathComponent)”. \(error.localizedDescription)")
        }
    }

    func reloadCurrent() {
        guard let index = currentDocumentIndex,
              let url = documents[index].url
        else { return }

        if documents[index].isDirty {
            let alert = NSAlert()
            alert.messageText = "Reload from disk?"
            alert.informativeText = "Unsaved changes in this tab will be discarded."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Reload")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            documents[index].content = content
            documents[index].lastSavedContent = content
            documents[index].fileModifiedAt = Date()
        } catch {
            present(error: "Couldn’t reload “\(url.lastPathComponent)”. \(error.localizedDescription)")
        }
    }

    func togglePin(for recent: RecentDocument) {
        guard let index = recentDocuments.firstIndex(where: { $0.path == recent.path }) else { return }
        recentDocuments[index].isPinned.toggle()
        if let documentIndex = documents.firstIndex(where: { $0.url?.path == recent.path }) {
            documents[documentIndex].isPinned = recentDocuments[index].isPinned
        }
        sortAndSaveRecents()
    }

    func removeRecent(_ recent: RecentDocument) {
        recentDocuments.removeAll { $0.path == recent.path }
        saveRecents()
    }

    func exportPDF() {
        guard let currentDocument else { return }
        rendererController.exportPDF(suggestedName: "\(currentDocument.title).pdf") { [weak self] error in
            if let error {
                self?.present(error: "Couldn’t export PDF. \(error.localizedDescription)")
            }
        }
    }

    func zoomIn() {
        zoom = min(1.6, (zoom + 0.1).rounded(toPlaces: 1))
    }

    func zoomOut() {
        zoom = max(0.7, (zoom - 0.1).rounded(toPlaces: 1))
    }

    func setCustomReadingWidth(_ value: Double) {
        customReadingWidth = min(1600, max(560, (value / 10).rounded() * 10))
        readingWidth = .custom
    }

    func fitWideContent() {
        readingWidth = .data
    }

    func updatePreferences() {
        defaults.set(theme.rawValue, forKey: themeKey)
        defaults.set(readingStyle.rawValue, forKey: styleKey)
        defaults.set(readingWidth.rawValue, forKey: widthKey)
        defaults.set(customReadingWidth, forKey: customWidthKey)
        defaults.set(usesPaperCanvas, forKey: paperKey)
    }

    private func loadPreferences() {
        if let rawTheme = defaults.string(forKey: themeKey),
           let savedTheme = PreviewTheme(rawValue: rawTheme) {
            theme = savedTheme
        }
        if let rawStyle = defaults.string(forKey: styleKey),
           let savedStyle = ReadingStyle(rawValue: rawStyle) {
            readingStyle = savedStyle
        }
        if let rawWidth = defaults.string(forKey: widthKey),
           let savedWidth = ReadingWidth(rawValue: rawWidth) {
            readingWidth = savedWidth
        }
        if defaults.object(forKey: customWidthKey) != nil {
            customReadingWidth = min(
                1600,
                max(560, defaults.double(forKey: customWidthKey))
            )
        }
        if defaults.object(forKey: paperKey) != nil {
            usesPaperCanvas = defaults.bool(forKey: paperKey)
        }
    }

    private func loadRecentDocuments() {
        guard let data = defaults.data(forKey: recentKey),
              let decoded = try? JSONDecoder().decode([RecentDocument].self, from: data)
        else { return }

        recentDocuments = decoded.filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
        sortAndSaveRecents()
    }

    private func touchRecent(_ url: URL) {
        let path = url.standardizedFileURL.path
        let existingPin = recentDocuments.first(where: { $0.path == path })?.isPinned ?? false
        recentDocuments.removeAll { $0.path == path }
        recentDocuments.append(
            RecentDocument(path: path, lastOpened: Date(), isPinned: existingPin)
        )
        sortAndSaveRecents()
    }

    private func sortAndSaveRecents() {
        recentDocuments.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.lastOpened > $1.lastOpened
        }
        if recentDocuments.count > 18 {
            recentDocuments = Array(recentDocuments.prefix(18))
        }
        saveRecents()
    }

    private func saveRecents() {
        guard let data = try? JSONEncoder().encode(recentDocuments) else { return }
        defaults.set(data, forKey: recentKey)
    }

    private func present(error: String) {
        errorMessage = error
        let alert = NSAlert()
        alert.messageText = "PreviewMD"
        alert.informativeText = error
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static var markdownContentTypes: [UTType] {
        MarkdownFileSupport.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
    }

}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
