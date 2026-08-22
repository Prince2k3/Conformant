//
//  ParseDiagnostic.swift
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

/// A problem found while reading a Swift source file.
///
/// Diagnostics exist so that "the parser could not see this code" is never confused with
/// "this code has no violations". They come from two places: syntax errors reported by
/// SwiftParser, and constructs the extractor recognized but could not represent.
public struct ParseDiagnostic: Hashable, Sendable {

    public enum Severity: String, Hashable, Sendable, Comparable {
        /// The source is not valid Swift, or could not be read. Anything extracted from
        /// this file is partial, so rules evaluated against it are unsound.
        case error

        /// The source is valid, but the extractor dropped something it does not model.
        /// Results are incomplete rather than wrong.
        case warning

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs == .error && rhs == .warning
        }
    }

    /// Why the diagnostic was raised. Callers can filter on this rather than matching
    /// on message text, which is not part of the API contract.
    public enum Category: String, Hashable, Sendable {
        /// SwiftParser could not parse the source.
        case syntaxError
        /// The file could not be read from disk.
        case unreadableFile
        /// A syntax node the extractor does not model yet. The declaration is still
        /// produced, but some detail (an attribute argument, a type form) is missing.
        case unsupportedConstruct
    }

    public let severity: Severity
    public let category: Category
    public let message: String
    public let location: SourceLocation

    public init(severity: Severity, category: Category, message: String, location: SourceLocation) {
        self.severity = severity
        self.category = category
        self.message = message
        self.location = location
    }

    /// `path:line:column: severity: message`, matching the layout compilers use.
    public var description: String {
        "\(location.file):\(location.line):\(location.column): \(severity.rawValue): \(message)"
    }
}

extension Sequence where Element == ParseDiagnostic {
    public var errors: [ParseDiagnostic] { filter { $0.severity == .error } }
    public var warnings: [ParseDiagnostic] { filter { $0.severity == .warning } }
    public var containsErrors: Bool { contains { $0.severity == .error } }

    /// Diagnostics in a stable order: by file, then position, then message.
    public func sortedForReporting() -> [ParseDiagnostic] {
        sorted {
            ($0.location.file, $0.location.line, $0.location.column, $0.message)
                < ($1.location.file, $1.location.line, $1.location.column, $1.message)
        }
    }

    /// A short, readable summary for failure messages, capped so a file with hundreds
    /// of cascading parse errors does not bury the actual problem.
    public func summary(limit: Int = 5) -> String {
        let all = sortedForReporting()
        guard !all.isEmpty else { return "<none>" }
        var lines = all.prefix(limit).map { "  \($0.description)" }
        if all.count > limit {
            lines.append("  … and \(all.count - limit) more")
        }
        return lines.joined(separator: "\n")
    }
}
