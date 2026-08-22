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
        let parser = SwiftSyntaxParser(
            dependencyDepth: policy.dependencyDepth,
            ignoresStandardLibraryTypes: policy.ignoresStandardLibraryTypes
        )
        var files: [SwiftFile] = []
        var diagnostics: [ParseDiagnostic] = []

        for url in urls {
            let file: SwiftFile
            do {
                file = try parser.parseFile(path: url.path)
            } catch let error as ConformantError {
                _ = try react(to: error, policy.onUnreadableFile).map { diagnostics.append(contentsOf: $0.diagnostics) }
                continue
            } catch {
                _ = try react(
                    to: .fileNotReadable(path: url.path, underlying: error),
                    policy.onUnreadableFile
                ).map { diagnostics.append(contentsOf: $0.diagnostics) }
                continue
            }

            files.append(file)
            diagnostics.append(contentsOf: file.diagnostics)
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
