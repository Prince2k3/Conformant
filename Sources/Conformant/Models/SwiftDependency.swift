import Foundation

/// Represents a dependency from one declaration/file to another type or module.
public struct SwiftDependency: Hashable {
    /// The name of the type or module being depended upon (e.g., "UIViewController", "Codable", "Foundation").
    public let name: String
    /// The kind of dependency relationship.
    public let kind: DependencyKind
    /// The location in the source file where this dependency occurs.
    public let location: SourceLocation

    // Implement Hashable for Set operations later if needed
    public static func == (lhs: SwiftDependency, rhs: SwiftDependency) -> Bool {
        return lhs.name == rhs.name && lhs.kind == rhs.kind &&
        lhs.location.file == rhs.location.file && // Basic location equality
        lhs.location.line == rhs.location.line &&
        lhs.location.column == rhs.location.column
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(kind)
        hasher.combine(location.file)
        hasher.combine(location.line)
        hasher.combine(location.column)
    }
}
