import Foundation

/// Represents a Swift struct declaration
public class SwiftStructDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let protocols: [String]
    public let properties: [SwiftPropertyDeclaration]
    public let methods: [SwiftFunctionDeclaration]

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        protocols: [String],
        properties: [SwiftPropertyDeclaration],
        methods: [SwiftFunctionDeclaration]
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.protocols = protocols
        self.properties = properties
        self.methods = methods
    }

    public func hasProperty(named name: String) -> Bool {
        return properties.contains { $0.name == name }
    }

    public func hasMethod(named name: String) -> Bool {
        return methods.contains { $0.name == name }
    }

    public func implements(protocol protocolName: String) -> Bool {
        return protocols.contains(protocolName)
    }
}
