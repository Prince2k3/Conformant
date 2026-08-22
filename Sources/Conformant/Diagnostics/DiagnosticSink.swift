//
//  DiagnosticSink.swift
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

/// Collects diagnostics raised while walking one file's syntax tree.
///
/// The extractor previously wrote unsupported-construct notices to standard output,
/// where they were invisible to the caller and to CI. Routing them through a sink makes
/// "I dropped something here" a value the scope can be queried for.
final class DiagnosticSink {
    private(set) var diagnostics: [ParseDiagnostic] = []

    func record(_ diagnostic: ParseDiagnostic) {
        diagnostics.append(diagnostic)
    }

    /// Records a construct the extractor recognized but does not model. The surrounding
    /// declaration is still produced; only this detail is missing.
    func unsupported(_ message: String, at location: SourceLocation) {
        record(ParseDiagnostic(
            severity: .warning,
            category: .unsupportedConstruct,
            message: message,
            location: location
        ))
    }

    func absorb(_ other: DiagnosticSink) {
        diagnostics.append(contentsOf: other.diagnostics)
    }
}
