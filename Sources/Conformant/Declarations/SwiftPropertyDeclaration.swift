import Foundation

/// Represents a Swift property declaration
public class SwiftPropertyDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let type: String
    public let isComputed: Bool
    public let initialValue: String?

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        type: String,
        isComputed: Bool,
        initialValue: String?
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.type = type
        self.isComputed = isComputed
        self.initialValue = initialValue
    }
}
