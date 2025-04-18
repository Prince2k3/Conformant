import Foundation

public struct AnySwiftDeclaration: SwiftDeclaration {
    private let _declaration: any SwiftDeclaration

    public init<ConcreteDecl: SwiftDeclaration>(_ declaration: ConcreteDecl) {
        self._declaration = declaration
    }

    public var name: String {
        _declaration.name
    }

    public var dependencies: [SwiftDependency] {
        _declaration.dependencies
    }

    public var modifiers: [SwiftModifier] {
        _declaration.modifiers
    }

    public var annotations: [SwiftAnnotation] {
        _declaration.annotations
    }

    public var filePath: String {
        _declaration.filePath
    }

    public var location: SourceLocation {
        _declaration.location
    }

    public func hasAnnotation(named name: String) -> Bool {
        _declaration.hasAnnotation(named: name)
    }

    public func hasModifier(_ modifier: SwiftModifier) -> Bool {
        _declaration.hasModifier(modifier)
    }

    public func resideInPackage(_ packagePattern: String) -> Bool {
        _declaration.resideInPackage(packagePattern)
    }
}
