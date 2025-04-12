//
//  SourceLocation.swift
//  SwiftArch
//
//  Created by Prince Ugwuh on 4/10/25.
//


// MARK: - Basic Components

/// Represents a source location
public struct SourceLocation: Hashable {
    public let file: String
    public let line: Int
    public let column: Int
    
    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }
}

/// Represents an import statement in a Swift file
public struct ImportStatement: Hashable {
    public let moduleName: String
    public let location: SourceLocation
    
    public init(moduleName: String, location: SourceLocation) {
        self.moduleName = moduleName
        self.location = location
    }
}

/// Represents a Swift attribute (like @available, @objc, custom attributes, etc.)
public struct SwiftAttribute: Hashable {
    public let name: String
    public let arguments: [String: String]
    public let location: SourceLocation
    
    public init(name: String, arguments: [String: String] = [:], location: SourceLocation) {
        self.name = name
        self.arguments = arguments
        self.location = location
    }
}

/// Base protocol for all Swift architectural components
public protocol ArchComponent: Hashable {
    var name: String { get }
    var fullyQualifiedName: String { get }
    var location: SourceLocation { get }
    var attributes: [SwiftAttribute] { get }
    var accessLevel: AccessLevel { get }
}

/// Represents access modifiers in Swift
public enum AccessLevel: String, Sendable {
    case `private` = "private"
    case `fileprivate` = "fileprivate"
    case `internal` = "internal"
    case `public` = "public"
    case `open` = "open"
    
    // Default if not specified is internal
    public static let `default`: AccessLevel = .internal
}

// MARK: - Type System

/// Represents the kind of Swift type
public enum SwiftTypeKind {
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case `extension`
    case `actor`
}

/// Protocol for all Swift types
public protocol SwiftType: ArchComponent {
    var kind: SwiftTypeKind { get }
    var methods: [SwiftMethod] { get }
    var properties: [SwiftProperty] { get }
    var nestedTypes: [any SwiftType] { get }
    var inheritedTypes: [TypeReference] { get }
    var conformances: [TypeReference] { get }
    var containingModule: SwiftModule { get }
}

/// Reference to a type (might be from another module)
public struct TypeReference: Hashable {
    public let name: String
    public let moduleName: String?
    
    public init(name: String, moduleName: String? = nil) {
        self.name = name
        self.moduleName = moduleName
    }
    
    public var fullyQualifiedName: String {
        if let moduleName = moduleName {
            return "\(moduleName).\(name)"
        }
        return name
    }
}

// MARK: - Methods and Properties

/// Represents a method or function in Swift
public struct SwiftMethod: ArchComponent {
    public let name: String
    public let fullyQualifiedName: String
    public let location: SourceLocation
    public let attributes: [SwiftAttribute]
    public let accessLevel: AccessLevel
    public let isStatic: Bool
    public let parameters: [MethodParameter]
    public let returnType: TypeReference?
    public let containingType: (any SwiftType)?
    public let isInitializer: Bool
    public let isOverride: Bool
    
    public init(
        name: String,
        fullyQualifiedName: String,
        location: SourceLocation,
        attributes: [SwiftAttribute] = [],
        accessLevel: AccessLevel = .default,
        isStatic: Bool = false,
        parameters: [MethodParameter] = [],
        returnType: TypeReference? = nil,
        containingType: (any SwiftType)? = nil,
        isInitializer: Bool = false,
        isOverride: Bool = false
    ) {
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.location = location
        self.attributes = attributes
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.parameters = parameters
        self.returnType = returnType
        self.containingType = containingType
        self.isInitializer = isInitializer
        self.isOverride = isOverride
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullyQualifiedName)
    }
    
    public static func == (lhs: SwiftMethod, rhs: SwiftMethod) -> Bool {
        return lhs.fullyQualifiedName == rhs.fullyQualifiedName
    }
}

/// Represents a method parameter
public struct MethodParameter: Hashable {
    public let label: String?
    public let name: String
    public let type: TypeReference
    public let hasDefaultValue: Bool
    
    public init(label: String? = nil, name: String, type: TypeReference, hasDefaultValue: Bool = false) {
        self.label = label
        self.name = name
        self.type = type
        self.hasDefaultValue = hasDefaultValue
    }
}

/// Represents a property in Swift
public struct SwiftProperty: ArchComponent {
    public let name: String
    public let fullyQualifiedName: String
    public let location: SourceLocation
    public let attributes: [SwiftAttribute]
    public let accessLevel: AccessLevel
    public let isStatic: Bool
    public let type: TypeReference
    public let containingType: (any SwiftType)?
    public let isComputed: Bool
    
    public init(
        name: String,
        fullyQualifiedName: String,
        location: SourceLocation,
        attributes: [SwiftAttribute] = [],
        accessLevel: AccessLevel = .default,
        isStatic: Bool = false,
        type: TypeReference,
        containingType: (any SwiftType)? = nil,
        isComputed: Bool = false
    ) {
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.location = location
        self.attributes = attributes
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.type = type
        self.containingType = containingType
        self.isComputed = isComputed
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullyQualifiedName)
    }
    
    public static func == (lhs: SwiftProperty, rhs: SwiftProperty) -> Bool {
        return lhs.fullyQualifiedName == rhs.fullyQualifiedName
    }
}

// MARK: - Module and Organization

/// Represents a Swift module (a framework or package)
public struct SwiftModule: Hashable {
    public let name: String
    public let types: [any SwiftType]
    public let imports: [ImportStatement]
    public let location: String // typically a directory path
    
    public init(name: String, types: [any SwiftType] = [], imports: [ImportStatement] = [], location: String) {
        self.name = name
        self.types = types
        self.imports = imports
        self.location = location
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func == (lhs: SwiftModule, rhs: SwiftModule) -> Bool {
        return lhs.name == rhs.name
    }
}

/// Represents a larger organizational grouping (e.g., an Xcode project, workspace, or package)
public struct SwiftTarget: Hashable {
    public let name: String
    public let modules: [SwiftModule]
    
    public init(name: String, modules: [SwiftModule] = []) {
        self.name = name
        self.modules = modules
    }
}

// MARK: - Dependencies and Relationships

/// Represents the kind of dependency between components
public enum DependencyKind {
    case inheritance
    case conformance
    case usage
    case instantiation
    case `import`
}

/// Represents a dependency relationship between two architectural components
public struct Dependency: Hashable {
    public let source: String  // fully qualified name of source component
    public let target: String  // fully qualified name of target component
    public let kind: DependencyKind
    public let location: SourceLocation
    
    public init(source: String, target: String, kind: DependencyKind, location: SourceLocation) {
        self.source = source
        self.target = target
        self.kind = kind
        self.location = location
    }
}

// MARK: - Concrete Type Implementations

/// Concrete implementation of a Swift class
public struct SwiftClass: SwiftType {
    public let name: String
    public let fullyQualifiedName: String
    public let location: SourceLocation
    public let attributes: [SwiftAttribute]
    public let accessLevel: AccessLevel
    public let methods: [SwiftMethod]
    public let properties: [SwiftProperty]
    public let nestedTypes: [any SwiftType]
    public let inheritedTypes: [TypeReference]
    public let conformances: [TypeReference]
    public let containingModule: SwiftModule
    public let kind: SwiftTypeKind = .class
    
    public init(
        name: String,
        fullyQualifiedName: String,
        location: SourceLocation,
        attributes: [SwiftAttribute] = [],
        accessLevel: AccessLevel = .default,
        methods: [SwiftMethod] = [],
        properties: [SwiftProperty] = [],
        nestedTypes: [any SwiftType] = [],
        inheritedTypes: [TypeReference] = [],
        conformances: [TypeReference] = [],
        containingModule: SwiftModule
    ) {
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.location = location
        self.attributes = attributes
        self.accessLevel = accessLevel
        self.methods = methods
        self.properties = properties
        self.nestedTypes = nestedTypes
        self.inheritedTypes = inheritedTypes
        self.conformances = conformances
        self.containingModule = containingModule
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullyQualifiedName)
    }
    
    public static func == (lhs: SwiftClass, rhs: SwiftClass) -> Bool {
        return lhs.fullyQualifiedName == rhs.fullyQualifiedName
    }
}

/// Concrete implementation of a Swift struct
public struct SwiftStruct: SwiftType {
    public let name: String
    public let fullyQualifiedName: String
    public let location: SourceLocation
    public let attributes: [SwiftAttribute]
    public let accessLevel: AccessLevel
    public let methods: [SwiftMethod]
    public let properties: [SwiftProperty]
    public let nestedTypes: [any SwiftType]
    public let inheritedTypes: [TypeReference]
    public let conformances: [TypeReference]
    public let containingModule: SwiftModule
    public let kind: SwiftTypeKind = .struct
    
    // Similar init as SwiftClass
    public init(
        name: String,
        fullyQualifiedName: String,
        location: SourceLocation,
        attributes: [SwiftAttribute] = [],
        accessLevel: AccessLevel = .default,
        methods: [SwiftMethod] = [],
        properties: [SwiftProperty] = [],
        nestedTypes: [any SwiftType] = [],
        inheritedTypes: [TypeReference] = [],
        conformances: [TypeReference] = [],
        containingModule: SwiftModule
    ) {
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.location = location
        self.attributes = attributes
        self.accessLevel = accessLevel
        self.methods = methods
        self.properties = properties
        self.nestedTypes = nestedTypes
        self.inheritedTypes = inheritedTypes
        self.conformances = conformances
        self.containingModule = containingModule
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullyQualifiedName)
    }
    
    public static func == (lhs: SwiftStruct, rhs: SwiftStruct) -> Bool {
        return lhs.fullyQualifiedName == rhs.fullyQualifiedName
    }
}

/// Concrete implementation of a Swift enum
public struct SwiftEnum: SwiftType {
    public let name: String
    public let fullyQualifiedName: String
    public let location: SourceLocation
    public let attributes: [SwiftAttribute]
    public let accessLevel: AccessLevel
    public let methods: [SwiftMethod]
    public let properties: [SwiftProperty]
    public let nestedTypes: [any SwiftType]
    public let inheritedTypes: [TypeReference]
    public let conformances: [TypeReference]
    public let containingModule: SwiftModule
    public let kind: SwiftTypeKind = .enum
    public let cases: [EnumCase]
    
    public init(
        name: String,
        fullyQualifiedName: String,
        location: SourceLocation,
        attributes: [SwiftAttribute] = [],
        accessLevel: AccessLevel = .default,
        methods: [SwiftMethod] = [],
        properties: [SwiftProperty] = [],
        nestedTypes: [any SwiftType] = [],
        inheritedTypes: [TypeReference] = [],
        conformances: [TypeReference] = [],
        containingModule: SwiftModule,
        cases: [EnumCase] = []
    ) {
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.location = location
        self.attributes = attributes
        self.accessLevel = accessLevel
        self.methods = methods
        self.properties = properties
        self.nestedTypes = nestedTypes
        self.inheritedTypes = inheritedTypes
        self.conformances = conformances
        self.containingModule = containingModule
        self.cases = cases
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullyQualifiedName)
    }
    
    public static func == (lhs: SwiftEnum, rhs: SwiftEnum) -> Bool {
        return lhs.fullyQualifiedName == rhs.fullyQualifiedName
    }
}

/// Represents a case in an enum
public struct EnumCase: Hashable {
    public let name: String
    public let associatedValues: [TypeReference]
    public let rawValue: String?
    
    public init(name: String, associatedValues: [TypeReference] = [], rawValue: String? = nil) {
        self.name = name
        self.associatedValues = associatedValues
        self.rawValue = rawValue
    }
}

/// Concrete implementation of a Swift protocol
public struct SwiftProtocol: SwiftType {
    public let name: String
    public let fullyQualifiedName: String
    public let location: SourceLocation
    public let attributes: [SwiftAttribute]
    public let accessLevel: AccessLevel
    public let methods: [SwiftMethod]
    public let properties: [SwiftProperty]
    public let nestedTypes: [any SwiftType]
    public let inheritedTypes: [TypeReference]
    public let conformances: [TypeReference]
    public let containingModule: SwiftModule
    public let kind: SwiftTypeKind = .protocol
    
    // Similar init as SwiftClass
    public init(
        name: String,
        fullyQualifiedName: String,
        location: SourceLocation,
        attributes: [SwiftAttribute] = [],
        accessLevel: AccessLevel = .default,
        methods: [SwiftMethod] = [],
        properties: [SwiftProperty] = [],
        nestedTypes: [any SwiftType] = [],
        inheritedTypes: [TypeReference] = [],
        conformances: [TypeReference] = [],
        containingModule: SwiftModule
    ) {
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.location = location
        self.attributes = attributes
        self.accessLevel = accessLevel
        self.methods = methods
        self.properties = properties
        self.nestedTypes = nestedTypes
        self.inheritedTypes = inheritedTypes
        self.conformances = conformances
        self.containingModule = containingModule
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullyQualifiedName)
    }
    
    public static func == (lhs: SwiftProtocol, rhs: SwiftProtocol) -> Bool {
        return lhs.fullyQualifiedName == rhs.fullyQualifiedName
    }
}

// Other concrete type implementations (SwiftExtension, SwiftActor) would follow the same pattern
