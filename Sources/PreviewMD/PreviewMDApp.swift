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
                .frame(minWidth: 920, minHeight: 620)
                .onAppear {
                    appDelegate.state = state
                }
        }
        .defaultSize(width: 1320, height: 840)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            PreviewMDCommands(state: state)
        }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 520, height: 360)
        }
    }
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

    var body: some Commands {
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
