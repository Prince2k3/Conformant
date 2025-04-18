import Foundation

/// Represents a location in the source code
public struct SourceLocation {
    let file: String
    let line: Int
    let column: Int
}

extension SourceLocation: Hashable {
    public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        lhs.file == rhs.file &&
        lhs.line == rhs.line &&
        lhs.column == rhs.column
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
        hasher.combine(line)
        hasher.combine(column)
    }
}
