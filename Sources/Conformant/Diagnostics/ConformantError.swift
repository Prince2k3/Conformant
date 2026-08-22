//
//  ConformantError.swift
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

/// A failure that prevented Conformant from building a trustworthy scope.
///
/// Every case here was previously a `print` followed by carrying on with fewer files.
/// That made the worst outcome — an empty scope, in which every architecture rule
/// trivially passes — indistinguishable from a clean codebase.
public enum ConformantError: Error, CustomStringConvertible {

    /// The path handed to a scope entry point does not exist.
    case pathDoesNotExist(path: String)

    /// A directory could not be enumerated.
    case directoryNotReadable(path: String, underlying: Error)

    /// A Swift file could not be read (permissions, or not valid UTF-8).
    case fileNotReadable(path: String, underlying: Error)

    /// One or more files are not valid Swift. Anything extracted from them is partial.
    case syntaxErrors(diagnostics: [ParseDiagnostic])

    /// The scope resolved to zero Swift files. Almost always a wrong path, and the most
    /// dangerous silent failure: rules over an empty scope all pass.
    case emptyScope(path: String)

    public var description: String {
        switch self {
        case .pathDoesNotExist(let path):
            return "Conformant: no such path '\(path)'."

        case .directoryNotReadable(let path, let underlying):
            return "Conformant: could not read directory '\(path)': \(underlying)"

        case .fileNotReadable(let path, let underlying):
            return "Conformant: could not read '\(path)': \(underlying)"

        case .syntaxErrors(let diagnostics):
            let fileCount = Set(diagnostics.errors.map(\.location.file)).count
            return """
            Conformant: \(diagnostics.errors.count) syntax error(s) in \(fileCount) file(s). \
            Declarations from these files are incomplete, so rules evaluated against them \
            would be unsound.
            \(diagnostics.errors.summary())
            """

        case .emptyScope(let path):
            return """
            Conformant: no Swift files found under '\(path)'. \
            Every rule would pass against an empty scope, so this is treated as a failure. \
            Check the path, or pass `policy: .lenient` if an empty scope is expected.
            """
        }
    }

    /// The diagnostics behind this failure, if any. Lets callers inspect specifics
    /// rather than parsing `description`.
    public var diagnostics: [ParseDiagnostic] {
        if case .syntaxErrors(let diagnostics) = self { return diagnostics }
        return []
    }
}
