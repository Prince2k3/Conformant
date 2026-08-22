//
//  SelfHostingTests.swift
//  Conformant
//
//  Copyright © 2025 Prince Ugwuh. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import XCTest
@testable import Conformant

/// Runs the parser over a large body of real Swift — the resolved swift-syntax
/// checkout — rather than over hand-written fixtures.
///
/// The corpus fixtures pin *known* constructs. This pins the parser against code nobody
/// wrote for it: hundreds of files using macros, generics, availability, and conditional
/// compilation in combinations the fixtures do not anticipate. It is the safety net for
/// the collector rewrite in later phases.
///
/// The corpus is large enough that these tests dominate the suite's runtime. Set
/// `CONFORMANT_SELF_HOSTING=0` to skip them during a tight edit loop; they are on by
/// default so CI always runs them.
final class SelfHostingTests: XCTestCase {

    private static var isEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["CONFORMANT_SELF_HOSTING"]
        return !(value == "0" || value == "false")
    }

    private func sourceFiles() throws -> [URL] {
        guard Self.isEnabled else {
            throw XCTSkip("Self-hosting tests disabled via CONFORMANT_SELF_HOSTING=0")
        }
        guard let root = CorpusLocator.swiftSyntaxSources else {
            throw XCTSkip("swift-syntax checkout not present — run `swift build` first")
        }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Could not enumerate \(root.path)")
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }

    /// Three guarantees, checked in a single pass over the corpus because parsing it is
    /// the expensive part and splitting them would pay that cost once per assertion:
    ///
    /// 1. Every file parses to completion without trapping.
    /// 2. No file reports a syntax error. swift-syntax's own sources compile, so an error
    ///    here is a false positive — and false positives make `.strict` scopes unusable
    ///    on real projects.
    /// 3. The run extracts a substantial number of declarations. A collector regression
    ///    that starts silently dropping declarations shows up as a collapsed count.
    func testParsesRealWorldCorpusCleanly() throws {
        let files = try sourceFiles()
        XCTAssertGreaterThan(files.count, 200, "Expected a substantial corpus")

        let parser = SwiftSyntaxParser()
        var declarationCount = 0
        var failures: [String] = []
        var filesWithErrors: [String] = []

        for file in files {
            let parsed: SwiftFile
            do {
                parsed = try parser.parseFile(path: file.path)
            } catch {
                failures.append("\(file.lastPathComponent): \(error)")
                continue
            }

            declarationCount += parsed.classes.count
                + parsed.structs.count
                + parsed.enums.count
                + parsed.protocols.count
                + parsed.extensions.count
                + parsed.functions.count
                + parsed.properties.count

            if parsed.hasSyntaxErrors {
                let detail = parsed.diagnostics.errors
                    .prefix(2)
                    .map { "line \($0.location.line): \($0.message)" }
                    .joined(separator: "; ")
                filesWithErrors.append("\(file.lastPathComponent) — \(detail)")
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Files failed to parse:\n\(failures.prefix(10).joined(separator: "\n"))"
        )
        XCTAssertTrue(
            filesWithErrors.isEmpty,
            """
            Valid Swift was reported as having syntax errors — the diagnostic pipeline \
            produces false positives:
            \(filesWithErrors.prefix(10).joined(separator: "\n"))
            """
        )
        XCTAssertGreaterThan(declarationCount, 2_000, "Extraction collapsed — expected thousands of declarations")
    }

    /// A strict scope over the whole corpus must build without throwing. This is the
    /// end-to-end version of the check above: if strictness rejects real, valid code, the
    /// default policy is unusable no matter how good the individual diagnostics are.
    func testStrictScopeBuildsOverRealWorldCorpus() throws {
        let files = try sourceFiles()
        let root = files[0].deletingLastPathComponent().deletingLastPathComponent()

        let scope = try Conformant.scope(directory: root.path)
        XCTAssertFalse(scope.isEmpty)
        XCTAssertFalse(scope.hasSyntaxErrors, scope.diagnostics.errors.summary())
    }

    /// Parsing must be a pure function of file contents.
    func testExtractionIsDeterministic() throws {
        let files = try sourceFiles().prefix(75)
        let parser = SwiftSyntaxParser()

        for file in files {
            let first = ExtractionSnapshot.render(try parser.parseFile(path: file.path), fixtureName: "x")
            let second = ExtractionSnapshot.render(try parser.parseFile(path: file.path), fixtureName: "x")
            XCTAssertEqual(first, second, "Extraction is not deterministic for \(file.lastPathComponent)")
        }
    }
}
