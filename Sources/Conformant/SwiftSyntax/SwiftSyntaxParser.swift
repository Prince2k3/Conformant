//
//  SwiftSyntaxParser.swift
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
import SwiftSyntax
import SwiftParser
import SwiftParserDiagnostics

/// Parser that uses SwiftSyntax to extract declarations from Swift files
public class SwiftSyntaxParser {

    public init() {}

    public func parseFile(path: String) throws -> SwiftFile {
        let url = URL(fileURLWithPath: path)
        let fileContent: String
        do {
            fileContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConformantError.fileNotReadable(path: FilePath.canonical(path), underlying: error)
        }
        return parse(source: fileContent, path: path)
    }

    /// Parses source held in memory. The path is recorded on the result but never read
    /// from disk, which makes the extractor testable without touching the file system.
    public func parse(source: String, path: String) -> SwiftFile {
        // Record a canonical path so declarations parsed through different
        // entry points (and through symlinked directories) compare equal.
        let canonicalPath = FilePath.canonical(path)
        let sourceFile: SourceFileSyntax = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: canonicalPath, tree: sourceFile)

        let sink = DiagnosticSink()
        // SwiftParser always returns a tree — invalid source yields error nodes rather
        // than a failure. Without this check a truncated file would be extracted as if
        // it were complete, and the declarations it lost would look like clean code.
        collectSyntaxDiagnostics(in: sourceFile, converter: converter, path: canonicalPath, into: sink)

        let collector = DeclarationCollector(filePath: canonicalPath, converter: converter, diagnostics: sink)
        collector.collect(from: sourceFile)
        return collector.makeSwiftFile()
    }

    private func collectSyntaxDiagnostics(
        in sourceFile: SourceFileSyntax,
        converter: SourceLocationConverter,
        path: String,
        into sink: DiagnosticSink
    ) {
        // `hasError` is a cheap flag on the tree; generating diagnostics is not, so only
        // pay for it when something is actually wrong.
        guard sourceFile.hasError else { return }

        for diagnostic in ParseDiagnosticsGenerator.diagnostics(for: sourceFile) {
            let position = converter.location(for: diagnostic.position)
            sink.record(ParseDiagnostic(
                severity: diagnostic.diagMessage.severity == .warning ? .warning : .error,
                category: .syntaxError,
                message: diagnostic.message,
                location: SourceLocation(file: path, line: position.line, column: position.column)
            ))
        }
    }
}
