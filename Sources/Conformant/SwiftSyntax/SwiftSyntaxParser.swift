import Foundation
import SwiftSyntax
import SwiftParser

/// Parser that uses SwiftSyntax to extract declarations from Swift files
public class SwiftSyntaxParser {
    public func parseFile(path: String) throws -> SwiftFile {
        let url = URL(fileURLWithPath: path)
        let fileContent = try String(contentsOf: url, encoding: .utf8)
        let sourceFile: SourceFileSyntax = Parser.parse(source: fileContent)
        let converter = SourceLocationConverter(fileName: path, tree: sourceFile)
        let visitor = SwiftSyntaxVisitor(filePath: path, converter: converter)
        visitor.walk(sourceFile)
        return visitor.makeSwiftFile()
    }
}
