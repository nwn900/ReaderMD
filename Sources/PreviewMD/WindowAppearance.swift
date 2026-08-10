import AppKit
import SwiftUI

@MainActor
enum WindowAppearanceController {
    static func apply(_ theme: PreviewTheme, to window: NSWindow) {
        let desiredName = appearanceName(for: theme)
        guard window.appearance?.name != desiredName else { return }

        window.appearance = desiredName.flatMap(NSAppearance.init(named:))
    }

    static func appearanceName(for theme: PreviewTheme) -> NSAppearance.Name? {
        switch theme {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }
}

extension View {
    /// Applies the reading theme to the enclosing AppKit window without
    /// replacing the SwiftUI hierarchy. Setting `NSWindow.appearance` to nil
    /// reliably returns an explicitly light or dark window to the system
    /// appearance, including on macOS versions where a live
    /// `preferredColorScheme` transition from a value to nil remains stuck.
    func previewWindowAppearance(_ theme: PreviewTheme) -> some View {
        background(WindowAppearanceBridge(theme: theme))
    }
}

private struct WindowAppearanceBridge: NSViewRepresentable {
    let theme: PreviewTheme

    func makeNSView(context: Context) -> WindowAppearanceView {
        let view = WindowAppearanceView(frame: .zero)
        view.theme = theme
        return view
    }

    func updateNSView(_ nsView: WindowAppearanceView, context: Context) {
        nsView.theme = theme
    }
}

@MainActor
private final class WindowAppearanceView: NSView {
    var theme: PreviewTheme = .system {
        didSet {
            guard theme != oldValue else { return }
            applyAppearance()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance()
    }

    private func applyAppearance() {
        guard let window else { return }
        WindowAppearanceController.apply(theme, to: window)
    }
}
