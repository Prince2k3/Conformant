import Foundation

/// Represents a Swift extension declaration
public class SwiftExtensionDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let properties: [SwiftPropertyDeclaration]
    public let methods: [SwiftFunctionDeclaration]
    public let protocols: [String]

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        properties: [SwiftPropertyDeclaration],
        methods: [SwiftFunctionDeclaration],
        protocols: [String]
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.properties = properties
        self.methods = methods
        self.protocols = protocols
    }

    public func implements(protocol protocolName: String) -> Bool {
        protocols.contains(protocolName)
    }
}
