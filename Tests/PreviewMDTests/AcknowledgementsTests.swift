#if canImport(XCTest)
import Foundation
import XCTest
@testable import PreviewMD

/// The bundled renderers are MIT/BSD licensed, which obliges us to ship their
/// copyright and license texts with every copy of the app. These notices were
/// once kept only in a repo-level Markdown file that nothing copied into the
/// bundle, so the shipped app carried none of them. These tests exist to keep
/// that from happening again — in particular, to fail loudly when a vendored
/// library is upgraded without its notice being updated in the same commit.
final class AcknowledgementsTests: XCTestCase {
    func testProjectLicenseAndOriginalAuthorAreAcknowledged() {
        let required = [
            "Apache License, Version 2.0",
            "Copyright 2026 Adam Jesionkiewicz and PreviewMD contributors",
            "Originally created by Adam Jesionkiewicz",
            "Contents/Resources/Legal"
        ]

        for fragment in required {
            XCTAssertTrue(
                Acknowledgements.text.contains(fragment),
                "project acknowledgements are missing: \(fragment)"
            )
        }
    }

    func testEveryVendoredLibraryIsNamedInTheNotices() {
        for library in Acknowledgements.vendoredLibraries {
            XCTAssertTrue(
                Acknowledgements.text.contains(library),
                "\(library) is vendored but missing from the acknowledgements"
            )
        }
    }

    /// MIT and BSD both require the license body, not just the license name.
    func testNoticesCarryFullLicenseTextsAndCopyrightHolders() {
        let required = [
            // MIT: the permission notice itself must travel with the copies.
            "The above copyright notice and this permission notice shall be",
            "THE SOFTWARE IS PROVIDED \"AS IS\"",
            // BSD-3-Clause: conditions plus disclaimer.
            "Redistributions in binary form must reproduce the above copyright",
            "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS",
            // Copyright holders, which minification stripped from the bundles.
            "Vitaly Puzrin, Alex Kocharin",
            "Knut Sveidqvist",
            "Khan Academy and other contributors",
            "Ivan Sagalaev"
        ]

        for fragment in required {
            XCTAssertTrue(
                Acknowledgements.text.contains(fragment),
                "acknowledgements are missing required text: \(fragment)"
            )
        }
    }

    /// Reads the vendored bundles straight off disk: the declared versions must
    /// match the code actually shipping, or the notices are describing software
    /// the user does not have.
    func testDeclaredVersionsMatchTheVendoredBundles() throws {
        let renderer = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PreviewMDTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Sources/PreviewMD/Resources/Renderer")

        // Each vendored bundle states its own version somewhere in the file;
        // the marker below is the shortest string unique to that statement.
        let expectations: [(file: String, marker: String, library: String)] = [
            ("markdown-it.min.js", "markdown-it 14.3.0", "markdown-it 14.3.0"),
            ("markdown-it-footnote.min.js", "footnote 4.0.0", "markdown-it-footnote 4.0.0"),
            ("mermaid.min.js", #"version:"11.16.0""#, "Mermaid 11.16.0"),
            ("katex.min.js", #"version:"0.16.47""#, "KaTeX 0.16.47"),
            ("highlight.min.js", #"versionString="11.11.1""#, "highlight.js 11.11.1")
        ]

        for expectation in expectations {
            let url = renderer.appendingPathComponent(expectation.file)
            let contents = try String(contentsOf: url, encoding: .utf8)

            XCTAssertTrue(
                contents.contains(expectation.marker),
                """
                \(expectation.file) no longer reports \(expectation.marker). \
                If it was upgraded, update Acknowledgements.swift — its license \
                text and version — in the same commit, then fix this expectation.
                """
            )

            XCTAssertTrue(
                Acknowledgements.vendoredLibraries.contains(expectation.library),
                "\(expectation.library) missing from Acknowledgements.vendoredLibraries"
            )
        }
    }
}
#endif
