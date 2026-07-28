import AppKit
import SwiftUI

@main
struct PreviewMDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        Window("PreviewMD", id: "main") {
            WorkspaceView()
                .environmentObject(state)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    appDelegate.state = state
                }
        }
        .defaultSize(width: 1360, height: 860)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            PreviewMDCommands(state: state)
        }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 520, height: 360)
        }

        // Replaces the standard About panel, which cannot show the bundled
        // renderers' license texts. `.commandsRemoved` keeps it out of the
        // Window menu; it is reached only from the app menu.
        Window("About PreviewMD", id: AboutWindow.id) {
            AboutView()
        }
        .defaultSize(width: 560, height: 620)
        .windowResizability(.contentMinSize)
        .commandsRemoved()
    }
}

enum AboutWindow {
    static let id = "about"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var state: AppState? {
        didSet {
            openPendingURLsIfPossible()
        }
    }

    private var pendingOpenURLs: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        openOrQueue(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func openOrQueue(_ urls: [URL]) {
        let supportedURLs = urls.filter(MarkdownFileSupport.accepts)
        guard !supportedURLs.isEmpty else { return }

        guard let state else {
            pendingOpenURLs.append(contentsOf: supportedURLs)
            return
        }

        supportedURLs.forEach(state.open)
    }

    private func openPendingURLsIfPossible() {
        guard let state, !pendingOpenURLs.isEmpty else { return }
        let urls = pendingOpenURLs
        pendingOpenURLs.removeAll()
        urls.forEach(state.open)
    }
}

struct PreviewMDCommands: Commands {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About PreviewMD") {
                openWindow(id: AboutWindow.id)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("Open…") {
                state.presentOpenPanel()
            }
            .keyboardShortcut("o")

            Divider()

            Button("Save") {
                state.saveCurrent()
            }
            .keyboardShortcut("s")
            .disabled(state.currentDocument == nil)

            Button("Save As…") {
                state.saveCurrentAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(state.currentDocument == nil)

            Divider()

            Button("Export as PDF…") {
                state.exportPDF()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(state.currentDocument == nil || state.displayMode == .source)
        }

        CommandGroup(after: .printItem) {
            Button("Close Tab") {
                state.closeCurrentTab()
            }
            .keyboardShortcut("w")
            .disabled(state.currentDocument == nil)
        }

        CommandMenu("View") {
            Picker("Display Mode", selection: $state.displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }

            Divider()

            Button(state.isInspectorVisible ? "Hide Outline" : "Show Outline") {
                state.isInspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Button("Focus Search") {
                state.searchFieldFocusToken = UUID()
            }
            .keyboardShortcut("f")

            Divider()

            Button("Actual Size") {
                state.zoom = 1
            }
            .keyboardShortcut("0")

            Button("Zoom In") {
                state.zoomIn()
            }
            .keyboardShortcut("+")

            Button("Zoom Out") {
                state.zoomOut()
            }
            .keyboardShortcut("-")
        }
    }
}
