import Foundation

/// Represents a Swift function declaration
public class SwiftFunctionDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let parameters: [SwiftParameterDeclaration]
    public let returnType: String?
    public let body: String?  // Function body as a string

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        parameters: [SwiftParameterDeclaration],
        returnType: String?,
        body: String?
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.parameters = parameters
        self.returnType = returnType
        self.body = body
    }

    public func hasParameter(named name: String) -> Bool {
        return parameters.contains { $0.name == name }
    }

    public func hasReturnType() -> Bool {
        return returnType != nil && returnType != "Void" && returnType != "()"
    }
}
