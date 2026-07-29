import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @EnvironmentObject private var state: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isDropTargeted = false
    @State private var isSearchPresented = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 176, max: 192)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: inspectorPresentation) {
            OutlineInspector()
                .inspectorColumnWidth(min: 180, ideal: 200, max: 232)
        }
        .searchable(
            text: $state.searchText,
            isPresented: $isSearchPresented,
            placement: .toolbar,
            prompt: "Find"
        )
        // Focus mode keeps this hierarchy and only hides the chrome, so the web
        // view is never rebuilt and the reader keeps their place in the page.
        .background(
            FocusWindowChrome(
                isFocusMode: state.isFocusMode,
                windowTitle: state.currentDocument?.title ?? "PreviewMD",
                sidebarVisibility: columnVisibility
            )
        )
        // No solid bar in focus mode — the blurred edge below it is the whole
        // transition, and a background would put a hard band back on top of it.
        .toolbarBackground(state.isFocusMode ? .hidden : .automatic, for: .windowToolbar)
        .focusModeEscape(isActive: state.isFocusMode) {
            state.exitFocusMode()
        }
        .onChange(of: state.isFocusMode) {
            if state.isFocusMode {
                columnVisibility = .detailOnly
                isSearchPresented = false
            }
        }
        // Focus mode empties the toolbar rather than removing it. The bar keeps
        // its system material, so the page scrolls up underneath it the way it
        // does everywhere else in macOS, and the window keeps its buttons.
        .toolbar {
            if state.isFocusMode {
                // Everything else goes; the bar itself stays, so the page scrolls
                // up under its system material and the window keeps its buttons.
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        state.exitFocusMode()
                    } label: {
                        Label("Exit Focus Mode", systemImage: "xmark")
                    }
                    .help("Leave focus mode (Esc)")
                }
            } else {
                ToolbarItem(placement: .navigation) {
                    Button {
                        state.presentOpenPanel()
                    } label: {
                        Label("Open", systemImage: "folder.badge.plus")
                    }
                    .help("Open Markdown (⌘O)")
                }

                // The principal slot holds the display picker and nothing else.
                // Anything added beside it makes SwiftUI drag the split view's
                // sidebar button across to sit next to it, out of the sidebar
                // column where it belongs.
                ToolbarItem(placement: .principal) {
                    Picker("Display mode", selection: $state.displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Image(systemName: mode.symbol)
                                .help(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 136)
                    .disabled(state.currentDocument == nil)
                }

                ToolbarItem(placement: .primaryAction) {
                    ToolbarUtilities()
                }
            }
        }
        .onChange(of: state.searchFieldFocusToken) {
            guard state.currentDocument != nil else { return }
            isSearchPresented = true
        }
        .onChange(of: state.theme) {
            state.updatePreferences()
        }
        .onChange(of: state.readingStyle) {
            state.updatePreferences()
        }
        .onChange(of: state.readingWidth) {
            state.updatePreferences()
        }
        .onChange(of: state.customReadingWidth) {
            state.updatePreferences()
        }
        .onChange(of: state.usesPaperCanvas) {
            state.updatePreferences()
        }
        .onChange(of: state.selectedDocumentID) {
            NSApplication.shared.mainWindow?.title = state.currentDocument?.title ?? "PreviewMD"
            if state.currentDocument == nil {
                isSearchPresented = false
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        ZStack {
            DetailBackground()

            VStack(spacing: 0) {
                if !state.documents.isEmpty && !state.isFocusMode {
                    DocumentTabBar()
                }

                if let document = state.currentDocument {
                    DocumentWorkspace(document: document)
                        .id(document.id)
                } else {
                    EmptyWorkspace()
                }
            }

            if isDropTargeted {
                DropOverlay()
                    .transition(.opacity)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let accepted = urls.filter(MarkdownFileSupport.accepts)
            accepted.forEach(state.open)
            return !accepted.isEmpty
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.16)) {
                isDropTargeted = targeted
            }
        }
    }

    private var inspectorPresentation: Binding<Bool> {
        Binding(
            get: {
                state.currentDocument != nil && state.isInspectorVisible
            },
            set: { newValue in
                state.isInspectorVisible = newValue
            }
        )
    }
}

enum FocusMetrics {
    /// Height of the unified toolbar the page has to clear in focus mode.
    static let toolbarHeight: Double = 52
}

/// The soft blurred edge the page passes under in focus mode.
///
/// macOS draws this itself for scroll views it owns, but the document lives in a
/// web view, so the system cannot know where the content is. A blur masked by a
/// vertical gradient gives the same read: fully blurred against the toolbar,
/// fading to nothing a little below it, with no line anywhere.
private struct TopEdgeBlur: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        GradientMaskedBlur(height: height)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? GradientMaskedBlur)?.fadeHeight = height
    }

    final class GradientMaskedBlur: NSVisualEffectView {
        var fadeHeight: CGFloat {
            didSet { needsLayout = true }
        }

        private let gradient = CAGradientLayer()

        init(height: CGFloat) {
            fadeHeight = height
            super.init(frame: .zero)
            material = .headerView
            blendingMode = .withinWindow
            state = .active
            wantsLayer = true
            // Layer coordinates start at the bottom, so 1 is the top edge.
            gradient.colors = [NSColor.black.cgColor, NSColor.clear.cgColor]
            gradient.startPoint = CGPoint(x: 0.5, y: 1)
            gradient.endPoint = CGPoint(x: 0.5, y: 0)
            layer?.mask = gradient
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            // The mask must not animate into place, or it lags behind resizing.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = bounds
            CATransaction.commit()
        }
    }
}

/// Owns the parts of the window SwiftUI will not hand over.
///
/// Two things cannot be expressed in SwiftUI here. `.searchable` cannot be
/// dropped for one state and kept for another — wrapping it in an `if` changes
/// the view's identity and rebuilds the web view, throwing away the reader's
/// place in the document. And the split view's own sidebar button cannot be
/// moved: SwiftUI parks it next to whatever sits in the principal slot.
/// `.toolbar(removing: .sidebarToggle)` does remove it, but takes the tracking
/// separator with it, and that separator is what lets the sidebar surface run up
/// through the title bar. Pulling the button out of the NSToolbar directly
/// leaves the separator in place, so the app declares its own button instead.
private struct FocusWindowChrome: NSViewRepresentable {
    let isFocusMode: Bool
    let windowTitle: String
    /// Not read directly — it is here so the representable updates when the
    /// sidebar opens or closes, which is when SwiftUI rebuilds the toolbar.
    let sidebarVisibility: NavigationSplitViewVisibility

    private static let systemSidebarToggle = "com.apple.SwiftUI.navigationSplitView.toggleSidebar"
    private static let systemSearchField = "com.apple.SwiftUI.search"

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let focused = isFocusMode
        let title = windowTitle
        // Not in a window yet on the first pass.
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            // `titlebarAppearsTransparent` stays false on purpose: the bar has
            // to keep its material, because that material is what blurs the text
            // passing beneath it. Only the content area is extended upwards.
            //
            // Always written, never toggled: a window restored with
            // fullSizeContentView still set would otherwise come back laid out
            // for a mode it is no longer in — which is what once left the
            // document area blank on launch.
            if focused {
                window.styleMask.insert(.fullSizeContentView)
            } else {
                window.styleMask.remove(.fullSizeContentView)
            }
            window.title = focused ? "" : title
            // The hairline under the bar is what makes the text look clipped
            // rather than passing beneath it. Mail draws no such line.
            window.titlebarSeparatorStyle = focused ? .none : .automatic

            guard let toolbar = window.toolbar else { return }
            // Removed, not hidden: hiding an item's view leaves its empty
            // capsule behind, and the search field ignores it entirely.
            // SwiftUI re-adds these on its next toolbar rebuild, which is why
            // this runs again whenever the sidebar opens or closes.
            guard focused else { return }
            let unwanted: Set<String> = [Self.systemSidebarToggle, Self.systemSearchField]
            for index in toolbar.items.indices.reversed()
            where unwanted.contains(toolbar.items[index].itemIdentifier.rawValue) {
                toolbar.removeItem(at: index)
            }
        }
    }
}

private extension View {
    /// Leaves focus mode on a bare Escape.
    ///
    /// A local event monitor rather than `onExitCommand`, because the web view
    /// owns first responder while you are reading and SwiftUI's key handling
    /// never sees the key.
    func focusModeEscape(isActive: Bool, perform action: @escaping () -> Void) -> some View {
        modifier(FocusModeEscape(isActive: isActive, action: action))
    }
}

private struct FocusModeEscape: ViewModifier {
    let isActive: Bool
    let action: () -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive, initial: true) { _, active in
                active ? install() : remove()
            }
            .onDisappear(perform: remove)
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.keyCode == 53, // Escape
                  event.modifierFlags.intersection(modifiers).isEmpty
            else {
                return event
            }
            action()
            return nil // swallow it, so nothing else reacts to the same press
        }
    }

    private func remove() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}

private struct DetailBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Color(nsColor: .windowBackgroundColor)
                .backgroundExtensionEffect()
                .ignoresSafeArea()
        } else {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        }
    }
}

private struct ToolbarUtilities: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ControlGroup {
            Menu {
                Picker("Style", selection: $state.readingStyle) {
                    ForEach(ReadingStyle.allCases) { style in
                        Label(style.title, systemImage: style.symbol).tag(style)
                    }
                }

                Divider()

                Picker("Theme", selection: $state.theme) {
                    ForEach(PreviewTheme.allCases) { theme in
                        Label(theme.title, systemImage: theme.symbol).tag(theme)
                    }
                }

                Divider()

                Picker("Reading width", selection: $state.readingWidth) {
                    ForEach(ReadingWidth.allCases) { width in
                        Label(
                            width == .custom
                                ? "Custom — \(Int(state.customReadingWidth)) px"
                                : width.title,
                            systemImage: width.symbol
                        )
                        .tag(width)
                    }
                }

                Toggle("Paper canvas", isOn: $state.usesPaperCanvas)

                Divider()

                Button("Actual Size") {
                    state.zoom = 1
                }
                Button("Zoom In") {
                    state.zoomIn()
                }
                Button("Zoom Out") {
                    state.zoomOut()
                }
            } label: {
                Label("Reading appearance", systemImage: "textformat.size")
            }
            .help("Reading appearance")

            Button {
                state.reloadCurrent()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(state.currentDocument?.url == nil)
            .help("Reload from disk")

            Menu {
                Button {
                    state.exportPDF()
                } label: {
                    Label("Export as PDF…", systemImage: "doc.richtext")
                }
                .disabled(state.displayMode == .source)

                if let url = state.currentDocument?.url {
                    Divider()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.path, forType: .string)
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(state.currentDocument == nil)

            Button {
                state.isInspectorVisible.toggle()
            } label: {
                Label("Outline", systemImage: "sidebar.right")
            }
            .disabled(state.currentDocument == nil)
            .help(state.isInspectorVisible ? "Hide outline" : "Show outline")

            // Only ever enters: the bar is stripped once focus mode is on, and
            // ⇧⌘F or Escape brings it back.
            Button {
                state.enterFocusMode()
            } label: {
                Label("Focus", systemImage: "rectangle.center.inset.filled")
            }
            .disabled(!state.canEnterFocusMode)
            .help("Focus mode — just the page (⇧⌘F)")
        }
        .controlGroupStyle(.navigation)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var state: AppState

    private var pinned: [RecentDocument] {
        state.recentDocuments.filter(\.isPinned)
    }

    private var recent: [RecentDocument] {
        state.recentDocuments.filter { !$0.isPinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    SidebarRow(
                        title: "Showcase",
                        subtitle: "Explore every renderer",
                        symbol: "sparkles.rectangle.stack",
                        isSelected: state.sidebarSelection == "welcome"
                    ) {
                        state.openWelcome()
                    }
                } header: {
                    BrandHeader()
                }

                if !pinned.isEmpty {
                    Section("Pinned") {
                        ForEach(pinned) { item in
                            RecentRow(item: item)
                        }
                    }
                }

                if !recent.isEmpty {
                    Section("Recent") {
                        ForEach(recent) { item in
                            RecentRow(item: item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            Button {
                state.presentOpenPanel()
            } label: {
                Label("Open Markdown…", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(.secondary)
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("PREVIEWMD")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.primary)
                Text("by Jesion")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .textCase(nil)
        .padding(.vertical, 7)
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, subtitle == nil ? 5 : 4)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .background(
                isSelected ? Color.accentColor.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RecentRow: View {
    @EnvironmentObject private var state: AppState
    let item: RecentDocument

    var body: some View {
        SidebarRow(
            title: item.title,
            subtitle: item.url.deletingLastPathComponent().lastPathComponent,
            symbol: item.isPinned ? "pin.fill" : "doc.text",
            isSelected: state.sidebarSelection == item.path
        ) {
            state.open(url: item.url)
        }
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") {
                state.togglePin(for: item)
            }
            Divider()
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("Remove from Recents", role: .destructive) {
                state.removeRecent(item)
            }
        }
    }
}

private struct DocumentTabBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(state.documents) { document in
                    TabButton(
                        document: document,
                        isSelected: state.selectedDocumentID == document.id,
                        select: { state.select(documentID: document.id) },
                        close: { state.closeTab(document.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct TabButton: View {
    let document: MarkdownDocument
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 7) {
                Image(systemName: document.isSample ? "sparkles" : "doc.text")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(document.title)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: 150)

                if document.isDirty {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                } else if isHovering || isSelected {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 29)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(
                isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Close Tab", action: close)
            if document.url != nil {
                Button("Show in Finder") {
                    if let url = document.url {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
        }
    }
}

private struct DocumentWorkspace: View {
    @EnvironmentObject private var state: AppState
    let document: MarkdownDocument

    var body: some View {
        VStack(spacing: 0) {
            switch state.displayMode {
            case .preview:
                PreviewPane(document: document)
            case .source:
                SourceEditor()
            case .split:
                HSplitView {
                    SourceEditor()
                        .frame(minWidth: 320)
                    PreviewPane(document: document)
                        .frame(minWidth: 420)
                }
            }

            if !state.isFocusMode {
                StatusBar(document: document)
            }
        }
    }
}

private struct PreviewPane: View {
    @EnvironmentObject private var state: AppState
    @State private var isDropTargeted = false
    let document: MarkdownDocument

    var body: some View {
        ZStack(alignment: .bottom) {
            MarkdownWebView(
                markdown: document.content,
                documentURL: document.url,
                theme: state.theme,
                readingStyle: state.readingStyle,
                readingWidth: state.effectiveReadingWidth,
                usesPaperCanvas: state.usesPaperCanvas,
                zoom: state.zoom,
                searchText: state.searchText,
                outlineTarget: state.outlineTarget,
                topInset: state.isFocusMode ? FocusMetrics.toolbarHeight : 0,
                controller: state.rendererController,
                onDropFiles: { urls in
                    urls
                        .filter(MarkdownFileSupport.accepts)
                        .forEach(state.open)
                },
                onDropTargeted: { targeted in
                    withAnimation(.easeOut(duration: 0.16)) {
                        isDropTargeted = targeted
                    }
                }
            )
            .background(Color(nsColor: .textBackgroundColor))
            // In focus mode the page runs up behind the toolbar's material, the
            // way a document does in Mail or Safari. The matching top inset is
            // handed to the renderer above, so the text still starts below the
            // bar rather than under it.
            .ignoresSafeArea(state.isFocusMode ? .container : [], edges: .top)
            .overlay(alignment: .top) {
                if state.isFocusMode {
                    TopEdgeBlur(height: FocusMetrics.toolbarHeight + 26)
                        .frame(height: FocusMetrics.toolbarHeight + 26)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
            }

            ReadingWidthRuler()
                .padding(.bottom, 14)

            if isDropTargeted {
                DropOverlay()
                    .transition(.opacity)
            }
        }
    }
}

private struct ReadingWidthRuler: View {
    @EnvironmentObject private var state: AppState
    @State private var isHovering = false

    private var widthBinding: Binding<Double> {
        Binding(
            get: { Double(state.effectiveReadingWidth) },
            set: { state.setCustomReadingWidth($0) }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    state.readingWidth = .comfortable
                }
            } label: {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reset to comfortable reading width")

            Slider(value: widthBinding, in: 560...1600)
                .controlSize(.small)
                .frame(width: 176)
                .help("Drag to adjust document width")

            Text("\(state.effectiveReadingWidth) px")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)

            Divider()
                .frame(height: 18)

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    state.fitWideContent()
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    Label("Fit tables", systemImage: "tablecells")
                    Image(systemName: "tablecells")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.readingWidth == .data ? Color.accentColor : .secondary)
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                state.readingWidth == .data
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear,
                in: Capsule()
            )
            .help("Use a wide layout for large tables and diagrams")
        }
        .padding(.leading, 10)
        .padding(.trailing, 7)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.75)
        }
        .shadow(
            color: .black.opacity(isHovering ? 0.15 : 0.10),
            radius: isHovering ? 12 : 8,
            y: 3
        )
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct SourceEditor: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            TextEditor(text: state.bindingForCurrentContent())
                .font(.system(size: 13.5, design: .monospaced))
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var state: AppState
    let document: MarkdownDocument

    var body: some View {
        HStack(spacing: 13) {
            HStack(spacing: 5) {
                Circle()
                    .fill(document.isDirty ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(document.isDirty ? "Edited" : "Saved")
            }

            Text("\(document.wordCount.formatted()) words")
            Text("\(document.readingMinutes) min read")

            Spacer()

            if !state.searchText.isEmpty {
                Label("Finding “\(state.searchText)”", systemImage: "magnifyingglass")
            }

            Text("\(Int(state.zoom * 100))%")
                .monospacedDigit()
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct OutlineInspector: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Document")
                        .font(.headline)
                    Text("Outline & insights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if state.currentOutline.isEmpty {
                        ContentUnavailableView(
                            "No Headings",
                            systemImage: "list.bullet.indent",
                            description: Text("Add headings to navigate this document.")
                        )
                        .controlSize(.small)
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OUTLINE")
                                .inspectorLabel()

                            ForEach(state.currentOutline) { heading in
                                Button {
                                    state.outlineTarget = nil
                                    DispatchQueue.main.async {
                                        state.outlineTarget = heading.id
                                    }
                                } label: {
                                    Text(heading.title)
                                        .font(.system(size: heading.level == 1 ? 12.5 : 11.5, weight: heading.level <= 2 ? .medium : .regular))
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, CGFloat(max(0, heading.level - 1)) * 11)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(heading.level == 1 ? .primary : .secondary)
                            }
                        }
                    }

                    if let document = state.currentDocument {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("INSIGHTS")
                                .inspectorLabel()

                            InsightRow(label: "Words", value: document.wordCount.formatted())
                            InsightRow(label: "Characters", value: document.characterCount.formatted())
                            InsightRow(label: "Read time", value: "\(document.readingMinutes) min")
                            InsightRow(label: "Headings", value: state.currentOutline.count.formatted())
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("LOCATION")
                                .inspectorLabel()
                            Text(document.displayPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(4)
                        }

                        FeatureSummary(markdown: document.content)
                    }
                }
                .padding(15)
            }
        }
    }
}

private struct InsightRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .font(.caption)
    }
}

private struct FeatureSummary: View {
    let markdown: String

    private var features: [(String, String)] {
        var result: [(String, String)] = []
        if markdown.contains("|") { result.append(("Tables", "tablecells")) }
        if markdown.contains("```mermaid") { result.append(("Diagrams", "point.3.connected.trianglepath.dotted")) }
        if markdown.contains("$$") || markdown.contains("\\[") { result.append(("Math", "sum")) }
        if markdown.contains("```") { result.append(("Code", "chevron.left.forwardslash.chevron.right")) }
        if markdown.contains("- [") { result.append(("Tasks", "checkmark.square")) }
        if markdown.contains("[^") { result.append(("Footnotes", "text.append")) }
        return result
    }

    var body: some View {
        if !features.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text("DETECTED")
                    .inspectorLabel()

                FlowLayout(spacing: 6) {
                    ForEach(features, id: \.0) { feature in
                        Label(feature.0, systemImage: feature.1)
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.quaternary.opacity(0.6), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 260
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension View {
    func inspectorLabel() -> some View {
        self
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }
}

private struct EmptyWorkspace: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.035)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
                        .accessibilityLabel("PreviewMD")

                    Text("Ready for your next document")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))

                    Text("Open a Markdown file or drop it anywhere in this window.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 9) {
                    Button {
                        state.presentOpenPanel()
                    } label: {
                        Label("Open Markdown…", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        state.openWelcome()
                    } label: {
                        Label("View Showcase", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.doc")
                    Text("Drop .md, .markdown or .txt")
                    Text("•")
                    Text("⌘O to open")
                }
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)

                if !state.recentDocuments.isEmpty {
                    VStack(spacing: 9) {
                        Text("RECENT")
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 8) {
                            ForEach(Array(state.recentDocuments.prefix(3))) { recent in
                                Button {
                                    state.open(url: recent.url)
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(Color.accentColor)
                                        Text(recent.title)
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 11.5, weight: .medium))
                                    .padding(.horizontal, 11)
                                    .frame(height: 30)
                                    .background(.quaternary.opacity(0.55), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: 190)
                                .help(recent.path)
                            }
                        }
                    }
                    .padding(.top, 5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 7])
                )
                .padding(24)

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text("Drop to open")
                    .font(.title3.weight(.semibold))
                Text("Open Markdown files as new tabs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Style", selection: $state.readingStyle) {
                    ForEach(ReadingStyle.allCases) { style in
                        Label(style.title, systemImage: style.symbol).tag(style)
                    }
                }

                Text(state.readingStyle.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Theme", selection: $state.theme) {
                    ForEach(PreviewTheme.allCases) { theme in
                        Label(theme.title, systemImage: theme.symbol).tag(theme)
                    }
                }

                Picker("Reading width", selection: $state.readingWidth) {
                    ForEach(ReadingWidth.allCases) { width in
                        Label(
                            width == .custom
                                ? "Custom — \(Int(state.customReadingWidth)) px"
                                : width.title,
                            systemImage: width.symbol
                        )
                        .tag(width)
                    }
                }

                Toggle("Show document as a paper canvas", isOn: $state.usesPaperCanvas)
            }

            // Describes what the renderer can set, not which engines set it.
            // The engines are named only where their licenses require it —
            // see Acknowledgements.swift and the About window.
            Section("Rendering") {
                LabeledContent("Markdown", value: "GitHub Flavored")
                LabeledContent("Diagrams", value: "Flowcharts & charts")
                LabeledContent("Math", value: "Inline & display")
                LabeledContent("Code", value: "Syntax highlighted")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: state.theme) { state.updatePreferences() }
        .onChange(of: state.readingStyle) { state.updatePreferences() }
        .onChange(of: state.readingWidth) { state.updatePreferences() }
        .onChange(of: state.customReadingWidth) { state.updatePreferences() }
        .onChange(of: state.usesPaperCanvas) { state.updatePreferences() }
    }
}
