import Foundation

/// Represents a Swift import declaration
public class SwiftImportDeclaration: SwiftDeclaration {
    /// The kind of import statement
    public enum ImportKind {
        case regular
        case typeOnly
        case component
    }

    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let kind: ImportKind
    public let submodules: [String]

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        kind: ImportKind,
        submodules: [String]
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.kind = kind
        self.submodules = submodules
    }

    /// Gets the full import path including submodules
    public var fullPath: String {
        if submodules.isEmpty {
            return name
        } else {
            return name + "." + submodules.joined(separator: ".")
        }
    }

    /// Returns true if this is an import of the specified module
    public func isImportOf(_ module: String) -> Bool {
        return name == module
    }

    /// Returns true if this import includes the specified type
    public func includesType(named typeName: String) -> Bool {
        return submodules.contains(typeName)
    }
}
