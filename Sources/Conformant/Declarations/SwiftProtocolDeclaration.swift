import Foundation

/// Represents a Swift protocol declaration
public class SwiftProtocolDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let inheritedProtocols: [String]
    public let propertyRequirements: [SwiftPropertyDeclaration]
    public let methodRequirements: [SwiftFunctionDeclaration]

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        inheritedProtocols: [String],
        propertyRequirements: [SwiftPropertyDeclaration],
        methodRequirements: [SwiftFunctionDeclaration]
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.inheritedProtocols = inheritedProtocols
        self.propertyRequirements = propertyRequirements
        self.methodRequirements = methodRequirements
    }

    public func inherits(protocol protocolName: String) -> Bool {
        return inheritedProtocols.contains(protocolName)
    }
}
