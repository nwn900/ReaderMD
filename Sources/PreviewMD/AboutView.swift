import AppKit
import SwiftUI

/// Replaces the standard AppKit About panel, which is too small to carry the
/// third-party license texts the bundled renderers require us to ship.
struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            acknowledgements
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppInfo.name)
                    .font(.title2.weight(.semibold))

                Text(AppInfo.versionSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(AppInfo.copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var acknowledgements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acknowledgements")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                Text(Acknowledgements.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }
}

/// Bundle metadata, with fallbacks so `swift run PreviewMD` — which has no
/// Info.plist — still shows something sensible during development.
enum AppInfo {
    static var name: String {
        string(for: "CFBundleName") ?? "PreviewMD"
    }

    static var versionSummary: String {
        guard let version = string(for: "CFBundleShortVersionString") else {
            return "Development build"
        }
        guard let build = string(for: "CFBundleVersion") else {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }

    static var copyright: String {
        string(for: "NSHumanReadableCopyright") ?? "© 2026 Adam Jesionkiewicz"
    }

    private static func string(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}
