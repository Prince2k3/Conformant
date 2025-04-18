import Foundation

/// Describes the nature of a dependency relationship.
public enum DependencyKind: Hashable {
    case inheritance
    case conformance
    case typeUsage
    case `extension`
    case `import`
}
