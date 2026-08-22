//
//  CorpusLocator.swift
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


import Foundation

/// Locates the on-disk corpus directories.
///
/// The corpus is addressed through `#filePath` rather than `Bundle.module` because
/// snapshots must be *writable* — re-recording (`CONFORMANT_RECORD=1`) rewrites the
/// expectation files in the source tree, which a copied bundle resource cannot do.
enum CorpusLocator {
    /// `Tests/ConformantTests/Corpus`
    static let root: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    /// Swift files that are parsed as data. Excluded from the test target in
    /// `Package.swift`, so nothing here is compiled.
    static let fixtures: URL = root.appendingPathComponent("Fixtures")

    /// Recorded extraction snapshots, one `.txt` per fixture.
    static let expectations: URL = root.appendingPathComponent("Expectations")

    /// The package root — `Corpus` sits three levels below it.
    static let packageRoot: URL = root
        .deletingLastPathComponent()   // ConformantTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // <package root>

    /// The resolved swift-syntax checkout, used as a large real-world corpus.
    /// Absent before `swift build`, so callers should skip rather than fail.
    static var swiftSyntaxSources: URL? {
        let url = packageRoot
            .appendingPathComponent(".build/checkouts/swift-syntax/Sources")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Every fixture, in a stable alphabetical order.
    static func fixtureURLs() throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func expectationURL(forFixtureNamed name: String) -> URL {
        expectations.appendingPathComponent(name).appendingPathExtension("txt")
    }

    /// True when the suite was asked to overwrite expectations instead of comparing.
    static var isRecording: Bool {
        let value = ProcessInfo.processInfo.environment["CONFORMANT_RECORD"]
        return value == "1" || value?.lowercased() == "true"
    }
}
