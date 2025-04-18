import Foundation

/// Represents a Swift enum declaration
public class SwiftEnumDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let cases: [EnumCase]
    public let properties: [SwiftPropertyDeclaration]
    public let methods: [SwiftFunctionDeclaration]
    public let rawType: String?
    public let protocols: [String]

    public struct EnumCase {
        public let name: String
        public let associatedValues: [String]?
        public let rawValue: String?
    }

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        cases: [EnumCase],
        properties: [SwiftPropertyDeclaration],
        methods: [SwiftFunctionDeclaration],
        rawType: String?,
        protocols: [String]
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.cases = cases
        self.properties = properties
        self.methods = methods
        self.rawType = rawType
        self.protocols = protocols
    }

    public func implements(protocol protocolName: String) -> Bool {
        return protocols.contains(protocolName)
    }
}
