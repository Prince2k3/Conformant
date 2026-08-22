//
//  ExtractionSnapshotTests.swift
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

/// Pins what the parser extracts from each corpus fixture.
///
/// These tests do not assert that extraction is *correct*; several fixtures record
/// behavior that is known to be wrong and is scheduled to change. They assert that
/// extraction is *stable*: any parser change shows up as a reviewable diff rather than
/// a silent shift in what architecture rules can see.
///
/// To accept new output after an intentional parser change:
///
///     CONFORMANT_RECORD=1 swift test --filter ExtractionSnapshotTests
///
/// then review the diff in `Tests/ConformantTests/Corpus/Expectations`.
final class ExtractionSnapshotTests: XCTestCase {

    func testFixturesMatchRecordedSnapshots() throws {
        let fixtures = try CorpusLocator.fixtureURLs()
        XCTAssertFalse(fixtures.isEmpty, "The corpus is empty — expected fixtures at \(CorpusLocator.fixtures.path)")

        let parser = SwiftSyntaxParser()
        var mismatches: [String] = []
        var recorded: [String] = []

        for fixture in fixtures {
            let name = fixture.deletingPathExtension().lastPathComponent
            let file = try parser.parseFile(path: fixture.path)
            let actual = ExtractionSnapshot.render(file, fixtureName: fixture.lastPathComponent)
            let expectationURL = CorpusLocator.expectationURL(forFixtureNamed: name)

            if CorpusLocator.isRecording {
                try FileManager.default.createDirectory(
                    at: CorpusLocator.expectations,
                    withIntermediateDirectories: true
                )
                try actual.write(to: expectationURL, atomically: true, encoding: .utf8)
                recorded.append(name)
                continue
            }

            guard let expected = try? String(contentsOf: expectationURL, encoding: .utf8) else {
                mismatches.append("""
                \(name): no recorded snapshot at \(expectationURL.path)
                Run `CONFORMANT_RECORD=1 swift test --filter ExtractionSnapshotTests` to create it.
                """)
                continue
            }

            if actual != expected {
                mismatches.append("\(name):\n\(firstDifference(expected: expected, actual: actual))")
            }
        }

        if CorpusLocator.isRecording {
            XCTFail("""
            Recorded \(recorded.count) snapshot(s): \(recorded.joined(separator: ", ")).
            Recording mode always fails so a CI run cannot silently rewrite the corpus.
            Review the diff, then re-run without CONFORMANT_RECORD.
            """)
            return
        }

        if !mismatches.isEmpty {
            XCTFail("""
            \(mismatches.count) fixture(s) no longer match their recorded extraction:

            \(mismatches.joined(separator: "\n\n"))
            """)
        }
    }

    /// Every fixture must have an expectation, and every expectation a fixture.
    /// Catches a fixture added without recording, or an expectation orphaned by a rename.
    func testCorpusAndExpectationsAreInSync() throws {
        let fixtureNames = Set(try CorpusLocator.fixtureURLs().map { $0.deletingPathExtension().lastPathComponent })
        let expectationNames = Set(
            (try? FileManager.default.contentsOfDirectory(at: CorpusLocator.expectations, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "txt" }
                .map { $0.deletingPathExtension().lastPathComponent } ?? []
        )

        XCTAssertTrue(
            fixtureNames.subtracting(expectationNames).isEmpty,
            "Fixtures without a recorded snapshot: \(fixtureNames.subtracting(expectationNames).sorted())"
        )
        XCTAssertTrue(
            expectationNames.subtracting(fixtureNames).isEmpty,
            "Snapshots with no matching fixture: \(expectationNames.subtracting(fixtureNames).sorted())"
        )
    }

    // MARK: - Helpers

    /// A full snapshot is too large to read in a failure log, so report the first
    /// differing line with a little surrounding context.
    private func firstDifference(expected: String, actual: String) -> String {
        let expectedLines = expected.components(separatedBy: "\n")
        let actualLines = actual.components(separatedBy: "\n")

        for index in 0..<max(expectedLines.count, actualLines.count) {
            let expectedLine = index < expectedLines.count ? expectedLines[index] : "<end of snapshot>"
            let actualLine = index < actualLines.count ? actualLines[index] : "<end of snapshot>"
            guard expectedLine != actualLine else { continue }

            let contextStart = max(0, index - 3)
            let context = expectedLines[contextStart..<index]
                .map { "     \($0)" }
                .joined(separator: "\n")

            return """
            \(context)
              line \(index + 1)
            -  expected: \(expectedLine)
            +  actual:   \(actualLine)
            """
        }
        return "  snapshots differ only in trailing whitespace"
    }
}
