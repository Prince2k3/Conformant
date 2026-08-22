//
//  ScopeBuilder.swift
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

/// Builds a scope from the file system under a `ScopePolicy`.
///
/// Discovery, parsing, and policy enforcement live here so that all three scope entry
/// points behave identically — previously each one had its own hand-rolled traversal,
/// its own set of skipped directories, and its own `print`-and-continue error handling.
struct ScopeBuilder {
    let policy: ScopePolicy

    struct Result {
        var files: [SwiftFile]
        var diagnostics: [ParseDiagnostic]
    }

    /// Directories that never contain first-party source. Matched exactly, not by
    /// substring: `contains` previously excluded any path with "Products" or
    /// "Frameworks" anywhere in its name, including legitimate source directories.
    private static let excludedDirectories: Set<String> = [
        ".build", "Pods", "Carthage", "DerivedData",
        "node_modules", "fastlane", "vendor", "Products", ".swiftpm"
    ]

    private static let excludedSuffixes = [".xcodeproj", ".xcworkspace", ".playground", ".framework"]

    // MARK: - Entry points

    func build(directory path: String) throws -> Result {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return try react(to: .pathDoesNotExist(path: path), policy.onUnreadableFile)
                ?? Result(files: [], diagnostics: [])
        }
        guard isDirectory.boolValue else {
            return try build(file: path)
        }

        let urls = try discoverSwiftFiles(under: path)
        var result = try parse(urls)

        if result.files.isEmpty {
            if let short = try react(to: .emptyScope(path: path), policy.onEmptyScope) {
                result.diagnostics.append(contentsOf: short.diagnostics)
            }
        }
        return result
    }

    func build(file path: String) throws -> Result {
        guard FileManager.default.fileExists(atPath: path) else {
            return try react(to: .pathDoesNotExist(path: path), policy.onUnreadableFile)
                ?? Result(files: [], diagnostics: [])
        }
        return try parse([URL(fileURLWithPath: path)])
    }

    // MARK: - Discovery

    private func discoverSwiftFiles(under path: String) throws -> [URL] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: path)
        var enumerationErrors: [(URL, Error)] = []

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                enumerationErrors.append((url, error))
                return true
            }
        ) else {
            _ = try react(
                to: .directoryNotReadable(path: path, underlying: CocoaError(.fileReadUnknown)),
                policy.onUnreadableFile
            )
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDirectory {
                if Self.excludedDirectories.contains(name)
                    || Self.excludedSuffixes.contains(where: { name.hasSuffix($0) }) {
                    enumerator.skipDescendants()
                }
                continue
            }

            if url.pathExtension == "swift" {
                urls.append(url)
            }
        }

        for (url, error) in enumerationErrors {
            _ = try react(to: .directoryNotReadable(path: url.path, underlying: error), policy.onUnreadableFile)
        }

        // Sort so that scope contents — and therefore rule output and frozen baselines —
        // do not depend on file system enumeration order.
        return urls.sorted { $0.path < $1.path }
    }

    // MARK: - Parsing

    private func parse(_ urls: [URL]) throws -> Result {
        var files: [SwiftFile] = []
        var diagnostics: [ParseDiagnostic] = []

        // Reading the outcomes back in URL order, on one thread, is what keeps the scope
        // reproducible: the same directory yields the same files in the same order, and a
        // policy set to `.fail` throws on the first failing file rather than on whichever
        // one happened to finish first.
        for outcome in parseInParallel(urls) {
            switch outcome {
            case .parsed(let file):
                files.append(file)
                diagnostics.append(contentsOf: file.diagnostics)
            case .failed(let error):
                _ = try react(to: error, policy.onUnreadableFile).map { diagnostics.append(contentsOf: $0.diagnostics) }
            }
        }

        let syntaxErrors = diagnostics.errors.filter { $0.category == .syntaxError }
        if !syntaxErrors.isEmpty, policy.onSyntaxError == .fail {
            throw ConformantError.syntaxErrors(diagnostics: syntaxErrors)
        }
        if policy.onSyntaxError == .ignore {
            diagnostics.removeAll { $0.category == .syntaxError }
        }

        return Result(files: files, diagnostics: diagnostics)
    }

    /// What reading and parsing one file produced. Failures are carried rather than thrown
    /// so that the policy — which may turn a failure into a diagnostic, or into nothing —
    /// is applied once, in order, after every file has been read.
    private enum Outcome {
        case parsed(SwiftFile)
        case failed(ConformantError)
    }

    /// Parses every file across the available cores and returns the outcomes in the order
    /// the URLs were given.
    ///
    /// Parsing is the expensive part of building a scope and each file is independent of
    /// every other, so a large project has no reason to read them one at a time. The work
    /// stays synchronous: making it `async` would push `Conformant.scope(...)` — and every
    /// test that calls it — into an async context for no gain.
    ///
    /// Each iteration writes to its own index and reads nothing another iteration writes,
    /// so the buffer needs no lock. `SwiftSyntaxParser` holds only its configuration and
    /// builds a fresh collector per file, so one instance serves them all.
    private func parseInParallel(_ urls: [URL]) -> [Outcome] {
        let parser = SwiftSyntaxParser(
            dependencyDepth: policy.dependencyDepth,
            ignoresStandardLibraryTypes: policy.ignoresStandardLibraryTypes,
            conditionalCompilation: policy.conditionalCompilation
        )

        // Handing a single file to the scheduler costs more than parsing it.
        guard urls.count > 1 else {
            return urls.map { parse($0, with: parser) }
        }

        return [Outcome](unsafeUninitializedCapacity: urls.count) { buffer, initialized in
            // Each iteration initialises its own element and reads no other, so sharing
            // the base address across threads is safe; the compiler cannot see that.
            nonisolated(unsafe) let base = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: urls.count) { index in
                (base + index).initialize(to: parse(urls[index], with: parser))
            }
            initialized = urls.count
        }
    }

    private func parse(_ url: URL, with parser: SwiftSyntaxParser) -> Outcome {
        do {
            return .parsed(try parser.parseFile(path: url.path))
        } catch let error as ConformantError {
            return .failed(error)
        } catch {
            return .failed(.fileNotReadable(path: url.path, underlying: error))
        }
    }

    // MARK: - Policy

    /// Applies a reaction to a failure. Returns diagnostics to merge when the reaction is
    /// `.warn`, `nil` when it is `.ignore`, and throws when it is `.fail`.
    private func react(to error: ConformantError, _ reaction: ScopePolicy.Reaction) throws -> Result? {
        switch reaction {
        case .fail:
            throw error
        case .warn:
            return Result(files: [], diagnostics: [Self.diagnostic(for: error)])
        case .ignore:
            return nil
        }
    }

    private static func diagnostic(for error: ConformantError) -> ParseDiagnostic {
        let path: String
        switch error {
        case .pathDoesNotExist(let value), .emptyScope(let value):
            path = value
        case .directoryNotReadable(let value, _), .fileNotReadable(let value, _):
            path = value
        case .syntaxErrors:
            path = "<multiple>"
        }
        return ParseDiagnostic(
            severity: .error,
            category: .unreadableFile,
            message: error.description,
            location: SourceLocation(file: path, line: 0, column: 0)
        )
    }
}
