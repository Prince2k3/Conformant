////
////  OneFile.swift
////  Conformant
////
////  Created by Prince Ugwuh on 4/18/25.
////
//
//public struct AnySwiftDeclaration: SwiftDeclaration {
//    private let _declaration: any SwiftDeclaration
//
//    public init<ConcreteDecl: SwiftDeclaration>(_ declaration: ConcreteDecl) {
//        self._declaration = declaration
//    }
//
//    public var name: String {
//        _declaration.name
//    }
//
//    public var dependencies: [SwiftDependency] {
//        _declaration.dependencies
//    }
//
//    public var modifiers: [SwiftModifier] {
//        _declaration.modifiers
//    }
//
//    public var annotations: [SwiftAnnotation] {
//        _declaration.annotations
//    }
//
//    public var filePath: String {
//        _declaration.filePath
//    }
//
//    public var location: SourceLocation {
//        _declaration.location
//    }
//
//    public func hasAnnotation(named name: String) -> Bool {
//        _declaration.hasAnnotation(named: name)
//    }
//
//    public func hasModifier(_ modifier: SwiftModifier) -> Bool {
//        _declaration.hasModifier(modifier)
//    }
//
//    public func resideInPackage(_ packagePattern: String) -> Bool {
//        _declaration.resideInPackage(packagePattern)
//    }
//}
//
///// Describes the nature of a dependency relationship.
//public enum DependencyKind: Hashable {
//    case inheritance
//    case conformance
//    case typeUsage
//    case `extension`
//    case `import`
//}
//
///// Represents a location in the source code
//public struct SourceLocation {
//    let file: String
//    let line: Int
//    let column: Int
//}
//
//extension SourceLocation: Hashable {
//    public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
//        lhs.file == rhs.file &&
//        lhs.line == rhs.line &&
//        lhs.column == rhs.column
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(file)
//        hasher.combine(line)
//        hasher.combine(column)
//    }
//}
//
///// Represents a Swift annotation (attribute in Swift terminology)
//public struct SwiftAnnotation {
//    let name: String
//    let arguments: [String: String]
//}
//
///// Represents a dependency from one declaration/file to another type or module.
//public struct SwiftDependency: Hashable {
//    /// The name of the type or module being depended upon (e.g., "UIViewController", "Codable", "Foundation").
//    public let name: String
//    /// The kind of dependency relationship.
//    public let kind: DependencyKind
//    /// The location in the source file where this dependency occurs.
//    public let location: SourceLocation
//
//    // Implement Hashable for Set operations later if needed
//    public static func == (lhs: SwiftDependency, rhs: SwiftDependency) -> Bool {
//        return lhs.name == rhs.name && lhs.kind == rhs.kind &&
//        lhs.location.file == rhs.location.file && // Basic location equality
//        lhs.location.line == rhs.location.line &&
//        lhs.location.column == rhs.location.column
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(name)
//        hasher.combine(kind)
//        hasher.combine(location.file)
//        hasher.combine(location.line)
//        hasher.combine(location.column)
//    }
//}
//
///// Represents a Swift source file
//public struct SwiftFile {
//    let path: String
//    let imports: [SwiftImportDeclaration]
//    let classes: [SwiftClassDeclaration]
//    let structs: [SwiftStructDeclaration]
//    let protocols: [SwiftProtocolDeclaration]
//    let extensions: [SwiftExtensionDeclaration]
//    let functions: [SwiftFunctionDeclaration]
//    let properties: [SwiftPropertyDeclaration]
//    let enums: [SwiftEnumDeclaration]
//
//    var internalDependencies: [SwiftDependency] {
//        var deps: [SwiftDependency] = []
//        deps.append(contentsOf: classes.flatMap { $0.dependencies })
//        deps.append(contentsOf: structs.flatMap { $0.dependencies })
//        deps.append(contentsOf: protocols.flatMap { $0.dependencies })
//        deps.append(contentsOf: extensions.flatMap { $0.dependencies })
//        deps.append(contentsOf: functions.flatMap { $0.dependencies })
//        deps.append(contentsOf: properties.flatMap { $0.dependencies })
//        deps.append(contentsOf: enums.flatMap { $0.dependencies })
//        return deps
//    }
//
//    /// Dependencies originating from import statements in this file.
//    var importDependencies: [SwiftDependency] {
//        return imports.map {
//            SwiftDependency(name: $0.name, kind: .import, location: $0.location)
//
//            // SwiftDependency(name: $0.fullPath, kind: .import, location: $0.location)
//        }
//    }
//}
//
///// Represents a Swift modifier like public, private, static, etc.
//public enum SwiftModifier: String {
//    case `public`
//    case `private`
//    case `fileprivate`
//    case `internal`
//    case `static`
//    case `class`
//    case `final`
//    case `open`
//    case `mutating`
//    case `override`
//}
//
///// Represents a Swift class declaration
//public class SwiftClassDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let superClass: String?
//    public let protocols: [String]
//    public let properties: [SwiftPropertyDeclaration]
//    public let methods: [SwiftFunctionDeclaration]
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        superClass: String?,
//        protocols: [String],
//        properties: [SwiftPropertyDeclaration],
//        methods: [SwiftFunctionDeclaration]
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.superClass = superClass
//        self.protocols = protocols
//        self.properties = properties
//        self.methods = methods
//    }
//
//    public func hasProperty(named name: String) -> Bool {
//        return properties.contains { $0.name == name }
//    }
//
//    public func hasMethod(named name: String) -> Bool {
//        return methods.contains { $0.name == name }
//    }
//
//    public func implements(protocol protocolName: String) -> Bool {
//        return protocols.contains(protocolName)
//    }
//
//    public func extends(class className: String) -> Bool {
//        return superClass == className
//    }
//}
//
///// Base protocol for all Swift declarations
//public protocol SwiftDeclaration {
//    var name: String { get }
//    var modifiers: [SwiftModifier] { get }
//    var annotations: [SwiftAnnotation] { get }
//    var dependencies: [SwiftDependency] { get }
//    var filePath: String { get }
//    var location: SourceLocation { get }
//
//    func hasAnnotation(named: String) -> Bool
//    func hasModifier(_ modifier: SwiftModifier) -> Bool
//    func resideInPackage(_ packagePattern: String) -> Bool
//}
//
///// Default implementation for SwiftDeclaration methods
//extension SwiftDeclaration {
//    public func hasAnnotation(named name: String) -> Bool {
//        annotations.contains { $0.name == name }
//    }
//
//    public func hasModifier(_ modifier: SwiftModifier) -> Bool {
//        modifiers.contains(modifier)
//    }
//
//    public func resideInPackage(_ packagePattern: String) -> Bool {
//        let regexPattern = packagePattern.replacingOccurrences(of: "..", with: ".*")
//
//        do {
//            let regex = try Regex(regexPattern)
//            return filePath.contains(regex)
//        } catch {
//            print("Invalid regex pattern: \(regexPattern) - \(error)")
//            return false
//        }
//    }
//}
//
///// Represents a Swift enum declaration
//public class SwiftEnumDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let cases: [EnumCase]
//    public let properties: [SwiftPropertyDeclaration]
//    public let methods: [SwiftFunctionDeclaration]
//    public let rawType: String?
//    public let protocols: [String]
//
//    public struct EnumCase {
//        public let name: String
//        public let associatedValues: [String]?
//        public let rawValue: String?
//    }
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        cases: [EnumCase],
//        properties: [SwiftPropertyDeclaration],
//        methods: [SwiftFunctionDeclaration],
//        rawType: String?,
//        protocols: [String]
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.cases = cases
//        self.properties = properties
//        self.methods = methods
//        self.rawType = rawType
//        self.protocols = protocols
//    }
//
//    public func implements(protocol protocolName: String) -> Bool {
//        return protocols.contains(protocolName)
//    }
//}
//
///// Represents a Swift extension declaration
//public class SwiftExtensionDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let properties: [SwiftPropertyDeclaration]
//    public let methods: [SwiftFunctionDeclaration]
//    public let protocols: [String]
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        properties: [SwiftPropertyDeclaration],
//        methods: [SwiftFunctionDeclaration],
//        protocols: [String]
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.properties = properties
//        self.methods = methods
//        self.protocols = protocols
//    }
//
//    public func implements(protocol protocolName: String) -> Bool {
//        protocols.contains(protocolName)
//    }
//}
//
///// Represents a Swift function declaration
//public class SwiftFunctionDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let parameters: [SwiftParameterDeclaration]
//    public let returnType: String?
//    public let body: String?  // Function body as a string
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        parameters: [SwiftParameterDeclaration],
//        returnType: String?,
//        body: String?
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.parameters = parameters
//        self.returnType = returnType
//        self.body = body
//    }
//
//    public func hasParameter(named name: String) -> Bool {
//        return parameters.contains { $0.name == name }
//    }
//
//    public func hasReturnType() -> Bool {
//        return returnType != nil && returnType != "Void" && returnType != "()"
//    }
//}
//
///// Represents a Swift import declaration
//public class SwiftImportDeclaration: SwiftDeclaration {
//    /// The kind of import statement
//    public enum ImportKind {
//        case regular
//        case typeOnly
//        case component
//    }
//
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let kind: ImportKind
//    public let submodules: [String]
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        kind: ImportKind,
//        submodules: [String]
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.kind = kind
//        self.submodules = submodules
//    }
//
//    /// Gets the full import path including submodules
//    public var fullPath: String {
//        if submodules.isEmpty {
//            return name
//        } else {
//            return name + "." + submodules.joined(separator: ".")
//        }
//    }
//
//    /// Returns true if this is an import of the specified module
//    public func isImportOf(_ module: String) -> Bool {
//        return name == module
//    }
//
//    /// Returns true if this import includes the specified type
//    public func includesType(named typeName: String) -> Bool {
//        return submodules.contains(typeName)
//    }
//}
//
///// Represents a Swift parameter declaration
//public class SwiftParameterDeclaration {
//    public let name: String
//    public let type: String
//    public let defaultValue: String?
//
//    init(name: String, type: String, defaultValue: String? = nil) {
//        self.name = name
//        self.type = type
//        self.defaultValue = defaultValue
//    }
//}
//
///// Represents a Swift property declaration
//public class SwiftPropertyDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let type: String
//    public let isComputed: Bool
//    public let initialValue: String?
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        type: String,
//        isComputed: Bool,
//        initialValue: String?
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.type = type
//        self.isComputed = isComputed
//        self.initialValue = initialValue
//    }
//}
//
///// Represents a Swift protocol declaration
//public class SwiftProtocolDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let inheritedProtocols: [String]
//    public let propertyRequirements: [SwiftPropertyDeclaration]
//    public let methodRequirements: [SwiftFunctionDeclaration]
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        inheritedProtocols: [String],
//        propertyRequirements: [SwiftPropertyDeclaration],
//        methodRequirements: [SwiftFunctionDeclaration]
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.inheritedProtocols = inheritedProtocols
//        self.propertyRequirements = propertyRequirements
//        self.methodRequirements = methodRequirements
//    }
//
//    public func inherits(protocol protocolName: String) -> Bool {
//        return inheritedProtocols.contains(protocolName)
//    }
//}
//
///// Represents a Swift struct declaration
//public class SwiftStructDeclaration: SwiftDeclaration {
//    public let name: String
//    public let modifiers: [SwiftModifier]
//    public let annotations: [SwiftAnnotation]
//    public let dependencies: [SwiftDependency]
//    public let filePath: String
//    public let location: SourceLocation
//    public let protocols: [String]
//    public let properties: [SwiftPropertyDeclaration]
//    public let methods: [SwiftFunctionDeclaration]
//
//    init(
//        name: String,
//        modifiers: [SwiftModifier],
//        annotations: [SwiftAnnotation],
//        dependencies: [SwiftDependency],
//        filePath: String,
//        location: SourceLocation,
//        protocols: [String],
//        properties: [SwiftPropertyDeclaration],
//        methods: [SwiftFunctionDeclaration]
//    ) {
//        self.name = name
//        self.modifiers = modifiers
//        self.annotations = annotations
//        self.dependencies = dependencies
//        self.filePath = filePath
//        self.location = location
//        self.protocols = protocols
//        self.properties = properties
//        self.methods = methods
//    }
//
//    public func hasProperty(named name: String) -> Bool {
//        return properties.contains { $0.name == name }
//    }
//
//    public func hasMethod(named name: String) -> Bool {
//        return methods.contains { $0.name == name }
//    }
//
//    public func implements(protocol protocolName: String) -> Bool {
//        return protocols.contains(protocolName)
//    }
//}
//
///// Parser that uses SwiftSyntax to extract declarations from Swift files
//public class SwiftSyntaxParser {
//    public func parseFile(path: String) throws -> SwiftFile {
//        let url = URL(fileURLWithPath: path)
//        let fileContent = try String(contentsOf: url, encoding: .utf8)
//        let sourceFile: SourceFileSyntax = Parser.parse(source: fileContent)
//        let converter = SourceLocationConverter(fileName: path, tree: sourceFile)
//        let visitor = SwiftSyntaxVisitor(filePath: path, converter: converter)
//        visitor.walk(sourceFile)
//        return visitor.makeSwiftFile()
//    }
//}
//
///// Visitor that walks the SwiftSyntax AST and collects declarations
//class SwiftSyntaxVisitor: SyntaxVisitor {
//    private let filePath: String
//    private let converter: SourceLocationConverter
//
//    private var imports: [SwiftImportDeclaration] = []
//    private var classes: [SwiftClassDeclaration] = []
//    private var structs: [SwiftStructDeclaration] = []
//    private var protocols: [SwiftProtocolDeclaration] = []
//    private var extensions: [SwiftExtensionDeclaration] = []
//    private var topLevelFunctions: [SwiftFunctionDeclaration] = []
//    private var topLevelProperties: [SwiftPropertyDeclaration] = []
//    private var enums: [SwiftEnumDeclaration] = []
//
//    // Updated initializer
//    init(filePath: String, converter: SourceLocationConverter) {
//        self.filePath = filePath
//        self.converter = converter
//        super.init(viewMode: .sourceAccurate)
//    }
//
//    // Helper to check if a node is a member of a type/extension
//    private func isMember(_ node: Syntax) -> Bool {
//        var current: Syntax? = node.parent // Start with the immediate parent
//
//        while let parent = current {
//            // Check if the parent is one of the container types where members reside
//            // Note: Members inside protocols define requirements.
//            if parent.is(MemberBlockSyntax.self) {
//                // If the parent is specifically a MemberBlockSyntax, it's definitely a member
//                // Check the MemberBlockSyntax's parent to see what kind of declaration it belongs to
//                if let grandparent = parent.parent {
//                    if grandparent.is(ClassDeclSyntax.self) ||
//                        grandparent.is(StructDeclSyntax.self) ||
//                        grandparent.is(EnumDeclSyntax.self) ||
//                        grandparent.is(ProtocolDeclSyntax.self) ||
//                        grandparent.is(ExtensionDeclSyntax.self) {
//                        return true // It's a member block of a supported type/extension
//                    }
//                }
//                // If it's a MemberBlockSyntax but not directly in one of the above,
//                // treat it as not a top-level member for our purposes (e.g., nested types)
//                // Or potentially continue searching upwards? For simplicity, let's count it as a member context.
//                return true
//            }
//
//            // Added check: If inside a function body, it's not a top-level property/function either
//            if parent.is(CodeBlockSyntax.self) && parent.parent?.is(FunctionDeclSyntax.self) == true {
//                return true // It's inside a function body
//            }
//
//            // Stop if we reach the top-level source file node
//            if parent.is(SourceFileSyntax.self) {
//                return false // Reached the top without finding a container type
//            }
//
//            // Move up to the next parent
//            current = parent.parent
//        }
//
//        // If the loop finishes without finding a relevant container or SourceFile,
//        // it means it's likely top-level or in an unsupported context.
//        return false
//    }
//
//    // Updated getLocation to use converter and accept Syntax node
//    private func getLocation(for node: Syntax) -> SourceLocation {
//        let location = node.startLocation(converter: converter)
//        return SourceLocation(
//            file: filePath,
//            line: location.line,
//            column: location.column
//        )
//    }
//
//    // --- Visit Methods for Container Types (Import, Class, Struct, Enum, Protocol, Extension) ---
//    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
//        let location = getLocation(for: Syntax(node))
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var moduleName = ""
//        var submodules: [String] = []
//        var determinedKind: SwiftImportDeclaration.ImportKind
//
//        let pathComponents = node.path
//        if let firstComponent = pathComponents.first {
//            moduleName = firstComponent.name.text
//
//            if pathComponents.count > 1 {
//                submodules = pathComponents.dropFirst().map { $0.name.text }
//            }
//        }
//
//        if node.importKindSpecifier != nil {
//            determinedKind = .typeOnly
//        } else if !submodules.isEmpty {
//            determinedKind = .component
//        } else {
//            determinedKind = .regular
//        }
//
//        let importDecl = SwiftImportDeclaration(
//            name: moduleName,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: [],
//            filePath: filePath,
//            location: location,
//            kind: determinedKind,
//            submodules: submodules
//        )
//
//        imports.append(importDecl)
//
//        return .skipChildren
//    }
//
//    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
//        let location = getLocation(for: Syntax(node))
//        let name = node.name.text
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var currentDependencies: [SwiftDependency] = []
//        var protocols: [String] = []
//        var rawType: String? = nil
//
//        var genericParameterNames = Set<String>()
//        if let genericClause = node.genericParameterClause {
//            for genericParam in genericClause.parameters {
//                genericParameterNames.insert(genericParam.name.text)
//            }
//        }
//
//        if let inheritanceClause = node.inheritanceClause {
//            for inheritance in inheritanceClause.inheritedTypes {
//                let typeSyntax = Syntax(inheritance.type)
//                let typeName = typeSyntax.trimmedDescription
//                let depLocation = getLocation(for: typeSyntax)
//
//
//                // Check common raw types (adjust list as needed) TODO:
//                let commonRawTypes = ["String", "Int", "UInt", "Float", "Double", "Character", "RawRepresentable"]
//                if rawType == nil, commonRawTypes.contains(where: { typeName.hasPrefix($0) }) {
//                    // Crude check for raw type - might need refinement for complex cases
//                    // Check if it's actually *just* the type name or conforms to RawRepresentable
//                    // For simplicity, we assume the first potential raw type is the one.
//                    rawType = typeName
//
//                    for extractedName in extractTypeNames(from: typeName) {
//                        currentDependencies.append(
//                            SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                        )
//                    }
//                } else {
//                    protocols.append(typeName)
//
//                    for extractedName in extractTypeNames(from: typeName) {
//                        currentDependencies.append(
//                            SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
//                        )
//                    }
//                }
//            }
//        }
//
//        if let genericClause = node.genericParameterClause {
//            for genericParam in genericClause.parameters {
//                if let constraintType = genericParam.inheritedType {
//                    let typeSyntax = Syntax(constraintType)
//                    let typeName = typeSyntax.trimmedDescription
//                    let depLocation = getLocation(for: typeSyntax)
//                    for extractedName in extractTypeNames(from: typeName) {
//                        currentDependencies.append(SwiftDependency(name: extractedName, kind: .conformance, location: depLocation))
//                    }
//                }
//            }
//        }
//
//        var cases: [SwiftEnumDeclaration.EnumCase] = []
//
//        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
//        memberVisitor.walk(node.memberBlock)
//        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//
//        for member in node.memberBlock.members {
//            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
//                for caseElement in caseDecl.elements {
//                    let caseName = caseElement.name.text
//                    var associatedValueStrings: [String]? = nil
//
//                    if let parameterClause = caseElement.parameterClause {
//                        associatedValueStrings = [] // Initialize only if clause exists
//                        for param in parameterClause.parameters {
//                            let typeSyntax = param.type
//                            let typeName = typeSyntax.trimmedDescription
//                            associatedValueStrings?.append(typeName) // Store raw string
//
//                            let depLocation = getLocation(for: Syntax(typeSyntax))
//                            for extractedName in extractTypeNames(from: typeName) {
//                                if !genericParameterNames.contains(extractedName) {
//                                    currentDependencies.append(
//                                        SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                                    )
//                                }
//                            }
//                        }
//                    }
//                    let rawValue = caseElement.rawValue?.value.trimmedDescription
//
//                    cases.append(SwiftEnumDeclaration.EnumCase(
//                        name: caseName,
//                        associatedValues: associatedValueStrings,
//                        rawValue: rawValue
//                    ))
//                }
//            }
//        }
//
//        let enumDecl = SwiftEnumDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            cases: cases,
//            properties: memberVisitor.properties,
//            methods: memberVisitor.methods,
//            rawType: rawType,
//            protocols: protocols
//        )
//
//        enums.append(enumDecl)
//
//        return .skipChildren
//    }
//
//    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
//        let location = getLocation(for: Syntax(node))
//        let name = node.name.text
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var currentDependencies: [SwiftDependency] = []
//        var superClass: String? = nil
//        var protocols: [String] = []
//
//        if let inheritanceClause = node.inheritanceClause {
//            for (index, inheritance) in inheritanceClause.inheritedTypes.enumerated() {
//                let typeSyntax = Syntax(inheritance.type)
//                let typeName = typeSyntax.trimmedDescription // Raw type string
//                let depLocation = getLocation(for: typeSyntax) // Location of the type name
//
//                // First type for a class *might* be the superclass. Heuristic: doesn't look like a common protocol name.
//                // This is imperfect. Proper semantic analysis is needed for 100% accuracy.
//                if index == 0 /* && !isLikelyProtocol(typeName) */ {
//                    superClass = typeName
//                    for extractedName in extractTypeNames(from: typeName) {
//                        currentDependencies.append(
//                            SwiftDependency(name: extractedName, kind: .inheritance, location: depLocation)
//                        )
//                    }
//                } else {
//                    protocols.append(typeName)
//
//                    for extractedName in extractTypeNames(from: typeName) {
//                        currentDependencies.append(
//                            SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
//                        )
//                    }
//                }
//            }
//        }
//
//        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
//        memberVisitor.walk(node.memberBlock)
//        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//
//        let classDecl = SwiftClassDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            superClass: superClass,
//            protocols: protocols,
//            properties: memberVisitor.properties,
//            methods: memberVisitor.methods
//        )
//        classes.append(classDecl)
//        return .skipChildren
//    }
//
//    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
//        let location = getLocation(for: Syntax(node))
//        let name = node.name.text
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var currentDependencies: [SwiftDependency] = []
//        var protocols: [String] = []
//
//        if let inheritanceClause = node.inheritanceClause {
//            protocols = inheritanceClause.inheritedTypes.map {
//                let typeSyntax = Syntax($0.type)
//                let typeName = typeSyntax.trimmedDescription
//                let depLocation = getLocation(for: typeSyntax)
//
//                for extractedName in extractTypeNames(from: typeName) {
//                    currentDependencies.append(
//                        SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
//                    )
//                }
//                return typeName
//            }
//        }
//
//        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
//        memberVisitor.walk(node.memberBlock)
//        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//
//        let structDecl = SwiftStructDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            protocols: protocols,
//            properties: memberVisitor.properties,
//            methods: memberVisitor.methods
//        )
//        structs.append(structDecl)
//        return .skipChildren
//    }
//
//    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
//        let location = getLocation(for: Syntax(node))
//        let name = node.name.text
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var currentDependencies: [SwiftDependency] = []
//        var inheritedProtocols: [String] = []
//
//        if let inheritanceClause = node.inheritanceClause {
//            inheritedProtocols = inheritanceClause.inheritedTypes.map {
//                let typeSyntax = Syntax($0.type)
//                let typeName = typeSyntax.trimmedDescription
//                let depLocation = getLocation(for: typeSyntax)
//
//                for extractedName in extractTypeNames(from: typeName) {
//                    currentDependencies.append(
//                        SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
//                    )
//                }
//
//                return typeName
//            }
//        }
//
//        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
//        memberVisitor.walk(node.memberBlock)
//        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//
//        let protocolDecl = SwiftProtocolDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            inheritedProtocols: inheritedProtocols,
//            propertyRequirements: memberVisitor.properties,
//            methodRequirements: memberVisitor.methods
//        )
//        protocols.append(protocolDecl)
//        return .skipChildren
//    }
//
//    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
//        let location = getLocation(for: Syntax(node))
//        let name = node.extendedType.trimmedDescription
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var currentDependencies: [SwiftDependency] = []
//        var protocols: [String] = []
//
//        if let inheritanceClause = node.inheritanceClause {
//            protocols = inheritanceClause.inheritedTypes.map {
//                let typeSyntax = Syntax($0.type)
//                let typeName = typeSyntax.trimmedDescription
//                let depLocation = getLocation(for: typeSyntax)
//
//                for extractedName in extractTypeNames(from: typeName) {
//                    currentDependencies.append(
//                        SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
//                    )
//                }
//
//                return typeName
//            }
//        }
//
//        let typeSyntax = Syntax(node.extendedType)
//        let typeName = typeSyntax.trimmedDescription
//        let depLocation = getLocation(for: typeSyntax)
//
//        for extractedName in extractTypeNames(from: typeName) {
//            currentDependencies.append(
//                SwiftDependency(name: extractedName, kind: .extension, location: depLocation)
//            )
//        }
//
//        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
//        memberVisitor.walk(node.memberBlock)
//        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
//
//        let extensionDecl = SwiftExtensionDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            properties: memberVisitor.properties,
//            methods: memberVisitor.methods,
//            protocols: protocols
//        )
//
//        extensions.append(extensionDecl)
//
//        return .skipChildren
//    }
//
//    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
//        var currentDependencies: [SwiftDependency] = []
//
//        if !isMember(Syntax(node)) {
//            let location = getLocation(for: Syntax(node))
//            let name = node.name.text
//            let modifiers = extractModifiers(from: node.modifiers)
//            let annotations = extractAnnotations(from: node.attributes)
//            let parameterList = node.signature.parameterClause.parameters
//            let parameters = extractParameters(from: parameterList)
//            let returnType = node.signature.returnClause?.type.trimmedDescription
//            let body = node.body?.trimmedDescription
//
//            parameterList.forEach { param in
//                let typeSyntax = Syntax(param.type)
//                let typeName = typeSyntax.trimmedDescription
//                let depLocation = getLocation(for: typeSyntax)
//
//                for extractedName in extractTypeNames(from: typeName) {
//                    currentDependencies.append(
//                        SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                    )
//                }
//            }
//
//            if let returnType = node.signature.returnClause {
//                let depLocation = getLocation(for: Syntax(returnType))
//                for extractedName in extractTypeNames(from: returnType.type.trimmedDescription) {
//                    currentDependencies.append(
//                        SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                    )
//                }
//            }
//
//            let functionDecl = SwiftFunctionDeclaration(
//                name: name,
//                modifiers: modifiers,
//                annotations: annotations,
//                dependencies: currentDependencies,
//                filePath: filePath,
//                location: location,
//                parameters: parameters,
//                returnType: returnType,
//                body: body
//            )
//            topLevelFunctions.append(functionDecl)
//        }
//
//        return .skipChildren
//    }
//
//    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
//        var currentDependencies: [SwiftDependency] = []
//
//        if !isMember(Syntax(node)) {
//            let modifiers = extractModifiers(from: node.modifiers)
//            let annotations = extractAnnotations(from: node.attributes)
//
//            for binding in node.bindings {
//                // Ensure it's a simple identifier pattern (e.g., `let x = 1`, not `let (a, b) = (1, 2)`)
//                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
//                    let location = getLocation(for: Syntax(pattern))
//                    let name = pattern.identifier.text
//
//                    var type: String = "Any"
//                    // Flag to avoid duplicate dependency if type inferred
//                    var dependencyCreated = false
//
//                    if let typeAnnotation = binding.typeAnnotation {
//                        let typeSyntax = Syntax(typeAnnotation.type)
//                        type = typeSyntax.trimmedDescription
//                        let depLocation = getLocation(for: typeSyntax)
//                        for extractedName in extractTypeNames(from: type) {
//                            currentDependencies.append(
//                                SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                            )
//                            dependencyCreated = true
//                        }
//                    }
//
//                    let initialValue = binding.initializer?.value
//
//                    if !dependencyCreated, let initializerExpr = initialValue {
//                        let inferredTypeName = inferTypeName(from: initializerExpr)
//                        if let inferredTypeName = inferredTypeName {
//                            type = inferredTypeName
//                            let depLocation = getLocation(for: Syntax(initializerExpr))
//
//                            for extractedName in extractTypeNames(from: inferredTypeName) {
//                                currentDependencies.append(
//                                    SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                                )
//                            }
//                        }
//                    }
//
//                    // Check if computed based on accessor block presence
//                    let isComputed = binding.accessorBlock != nil
//                    let propertyDecl = SwiftPropertyDeclaration(
//                        name: name,
//                        modifiers: modifiers,
//                        annotations: annotations,
//                        dependencies: currentDependencies,
//                        filePath: filePath,
//                        location: location,
//                        type: type,
//                        isComputed: isComputed,
//                        initialValue: initialValue?.trimmedDescription
//                    )
//                    topLevelProperties.append(propertyDecl)
//                }
//            }
//        }
//
//        return .skipChildren
//    }
//
//    /// Attempts to infer a base type name from a common initializer expression syntax.
//    /// Returns a simplified type name string or nil if inference fails.
//    private func inferTypeName(from expression: ExprSyntax) -> String? {
//        if let funcCall = expression.as(FunctionCallExprSyntax.self) {
//            // Handles SomeType(...) or SomeModule.SomeType(...)
//            return inferTypeName(from: funcCall.calledExpression) // Recurse on the expression being called
//        } else if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
//            // Handles variable.method(...) or variable.property or EnumType.case
//            // We are interested in the type of the base, e.g. "EnumType" from EnumType.case
//            // If base is nil, it's implicit self or static member access like ".zero" - hard to infer type here.
//            if let base = memberAccess.base {
//                return inferTypeName(from: base) // Recurse on the base
//            } else {
//                // Attempt to get type from the member name if it's a static member/enum case? Heuristic.
//                // e.g., ".shared" -> could be anything. Need context.
//                // Let's return nil for implicit base for now.
//                return nil
//            }
//        } else if let identifier = expression.as(DeclReferenceExprSyntax.self) {
//            // Handles SomeType (e.g., in SomeType.init(...)) or variable names
//            let name = identifier.baseName.text
//            // Simple heuristic: If it starts with uppercase, assume it's a type name.
//            if name.first?.isUppercase == true {
//                return name
//            }
//        }
//        //        else if let explicitMember = expression.as(ExplicitMemberExprSyntax.self) {
//        //            // Handles .case(...) or .staticMember(...)
//        //            // Try to infer from base type if possible
//        //            if let base = explicitMember.base {
//        //                return inferTypeName(from: base)
//        //            } else {
//        //                // e.g. ".shared" called directly, cannot infer base type easily
//        //                return nil
//        //            }
//        //        }
//
//        // Fallback
//        return nil
//    }
//
//    func extractTypeNames(from typeString: String?) -> Set<String> {
//        guard let cleaned = typeString?.trimmingCharacters(in: .whitespacesAndNewlines) else { return [] }
//        // Very basic: remove common wrappers and split by non-alphanumeric
//        let baseTypes = cleaned
//            .replacingOccurrences(of: "?", with: "")
//            .replacingOccurrences(of: "!", with: "")
//            .replacingOccurrences(of: "[", with: "")
//            .replacingOccurrences(of: "]", with: "")
//            .replacingOccurrences(of: ":", with: "")
//            .components(separatedBy: CharacterSet.alphanumerics.inverted)
//            .filter { !$0.isEmpty && $0.first?.isUppercase == true } // Keep only potential type names
//
//        // TODO: Add common lowercase types like 'any', 'some' if needed
//
//        return Set(baseTypes)
//    }
//
//    func extractModifiers(from modifierList: DeclModifierListSyntax?) -> [SwiftModifier] {
//        var modifiers: [SwiftModifier] = []
//        guard let modifierList = modifierList else {
//            return modifiers
//        }
//
//        for modifier in modifierList {
//            let name = modifier.name.text
//
//            if let swiftModifier = SwiftModifier(rawValue: name) {
//                modifiers.append(swiftModifier)
//            }
//        }
//
//        return modifiers
//    }
//
//    func extractAnnotations(from attributeList: AttributeListSyntax?) -> [SwiftAnnotation] {
//        var annotations: [SwiftAnnotation] = []
//        guard let attributeList = attributeList else { return annotations }
//
//        for attributeElement in attributeList {
//            // Attributes can be wrapped in #if blocks, handle AttributeSyntax directly
//            guard let attribute = attributeElement.as(AttributeSyntax.self) else {
//                // Skip if it's not a simple attribute (e.g., inside #if)
//                continue
//            }
//
//            let name = attribute.attributeName.trimmedDescription
//            var arguments: [String: String] = [:]
//
//            // Handle different argument syntaxes using the enum cases of AttributeSyntax.Arguments
//            if let args = attribute.arguments {
//                switch args {
//                case .argumentList(let tupleExprElements):
//                    for element in tupleExprElements {
//                        let label = element.label?.text
//                        let value = element.expression.trimmedDescription
//
//                        // Determine the key for the arguments dictionary
//                        // Use label if it exists, otherwise use "_" for unnamed/positional args
//                        // Note: Multiple unnamed args will overwrite the "_" key here.
//                        // A list might be better for unnamed args if order/multiplicity matters.
//                        let key = label ?? "_"
//
//                        arguments[key] = value
//                    }
//                case .string(let stringLiteralExprSyntax):
//                    // Handles hypothetical @Attribute("someString") syntax if ever used
//                    // This case seems less common for typical attributes.
//                    arguments["_"] = stringLiteralExprSyntax.segments.trimmedDescription
//                case .availability(let availabilityArgumentListSyntax):
//                    for syntax in availabilityArgumentListSyntax {
//                        let argument = Syntax(syntax.argument)
//                        if argument.is(PlatformVersionSyntax.self) {
//                            let version = argument.cast(PlatformVersionSyntax.self)
//                            arguments[version.platform.text] = version.version?.trimmedDescription
//                        }
//                    }
//                default:
//                    print("Unhandled attribute argument type: \(args.syntaxNodeType) for attribute \(name)")
//                }
//            }
//            annotations.append(SwiftAnnotation(name: name, arguments: arguments))
//        }
//        return annotations
//    }
//
//    func extractParameters(from parameterList: FunctionParameterListSyntax) -> [SwiftParameterDeclaration] {
//        return parameterList.map { parameter in
//            // Handle cases like `_ name: Type` or `name: Type`
//            let name = parameter.secondName?.text ?? parameter.firstName.text
//            // Handle type variations (simple, optional, closure, etc.)
//            let type = parameter.type.trimmedDescription
//            let defaultValue = parameter.defaultValue?.value.trimmedDescription
//            return SwiftParameterDeclaration(name: name, type: type, defaultValue: defaultValue)
//        }
//    }
//
//    func makeSwiftFile() -> SwiftFile {
//        SwiftFile(
//            path: filePath,
//            imports: imports,
//            classes: classes,
//            structs: structs,
//            protocols: protocols,
//            extensions: extensions,
//            functions: topLevelFunctions,
//            properties: topLevelProperties,
//            enums: enums
//        )
//    }
//}
//
///// Helper class to collect members from declarations
//class MemberCollector: SyntaxVisitor {
//    var properties: [SwiftPropertyDeclaration] = []
//    var methods: [SwiftFunctionDeclaration] = []
//    private let filePath: String
//    private let converter: SourceLocationConverter
//
//    init(filePath: String, converter: SourceLocationConverter, viewMode: SyntaxTreeViewMode = .sourceAccurate) {
//        self.filePath = filePath
//        self.converter = converter
//        super.init(viewMode: viewMode)
//    }
//
//    private func getLocation(for node: Syntax) -> SourceLocation {
//        let location = node.startLocation(converter: converter)
//        return SourceLocation(
//            file: filePath,
//            line: location.line,
//            column: location.column
//        )
//    }
//
//    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
//        var currentDependencies: [SwiftDependency] = []
//
//        let location = getLocation(for: Syntax(node))
//        let name = "init"
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//        let parameterList = node.signature.parameterClause.parameters
//        let parameters = extractParameters(from: parameterList)
//        let returnType: String? = nil
//        let body = node.body?.trimmedDescription
//
//        parameterList.forEach { param in
//            let typeSyntax = Syntax(param.type)
//            let typeName = typeSyntax.trimmedDescription
//            let depLocation = getLocation(for: typeSyntax)
//
//            for extractedName in extractTypeNames(from: typeName) {
//                currentDependencies.append(
//                    SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                )
//            }
//        }
//
//        let initDecl = SwiftFunctionDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            parameters: parameters,
//            returnType: returnType,
//            body: body
//        )
//
//        methods.append(initDecl)
//
//        return .skipChildren
//    }
//
//    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
//        var currentDependencies: [SwiftDependency] = []
//
//        let location = getLocation(for: Syntax(node))
//        let name = node.name.text
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//        let parameterList = node.signature.parameterClause.parameters
//        let parameters = extractParameters(from: parameterList)
//        let returnType = node.signature.returnClause?.type.trimmedDescription
//        let body = node.body?.trimmedDescription
//
//        parameterList.forEach { param in
//            let typeSyntax = Syntax(param.type)
//            let typeName = typeSyntax.trimmedDescription
//            let depLocation = getLocation(for: typeSyntax)
//
//            for extractedName in extractTypeNames(from: typeName) {
//                currentDependencies.append(
//                    SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                )
//            }
//        }
//
//        if let returnType = node.signature.returnClause {
//            let depLocation = getLocation(for: Syntax(returnType))
//            for extractedName in extractTypeNames(from: returnType.type.trimmedDescription) {
//                currentDependencies.append(
//                    SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                )
//            }
//        }
//
//        let functionDecl = SwiftFunctionDeclaration(
//            name: name,
//            modifiers: modifiers,
//            annotations: annotations,
//            dependencies: currentDependencies,
//            filePath: filePath,
//            location: location,
//            parameters: parameters,
//            returnType: returnType,
//            body: body
//        )
//        methods.append(functionDecl)
//        return .skipChildren
//    }
//
//    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
//        let modifiers = extractModifiers(from: node.modifiers)
//        let annotations = extractAnnotations(from: node.attributes)
//
//        var currentDependencies: [SwiftDependency] = []
//
//        for binding in node.bindings {
//            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
//                let location = getLocation(for: Syntax(pattern))
//                let name = pattern.identifier.text
//                let isComputed = binding.accessorBlock != nil
//
//                var type: String = "Any"
//                // Flag to avoid duplicate dependency if type inferred
//                var dependencyCreated = false
//
//                if let typeAnnotation = binding.typeAnnotation {
//                    let typeSyntax = Syntax(typeAnnotation.type)
//                    type = typeSyntax.trimmedDescription
//                    let extractedNames = extractTypeNames(from: type)
//                    let depLocation = getLocation(for: typeSyntax)
//                    for extractedName in extractedNames {
//                        currentDependencies.append(
//                            SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                        )
//                        dependencyCreated = true
//                    }
//                }
//
//                let initialValue = binding.initializer?.value
//
//                if !dependencyCreated, let initializerExpr = initialValue {
//                    let inferredTypeName = inferTypeName(from: initializerExpr)
//                    if let inferredTypeName = inferredTypeName {
//                        type = inferredTypeName
//                        let depLocation = getLocation(for: Syntax(initializerExpr))
//
//                        for extractedName in extractTypeNames(from: inferredTypeName) {
//                            currentDependencies.append(
//                                SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
//                            )
//                        }
//                    }
//                }
//
//                let propertyDecl = SwiftPropertyDeclaration(
//                    name: name,
//                    modifiers: modifiers,
//                    annotations: annotations,
//                    dependencies: currentDependencies,
//                    filePath: filePath,
//                    location: location,
//                    type: type,
//                    isComputed: isComputed,
//                    initialValue: initialValue?.trimmedDescription
//                )
//                properties.append(propertyDecl)
//            }
//        }
//
//        return .skipChildren
//    }
//
//    // --- Helper Methods ---
//
//    /// Attempts to infer a base type name from a common initializer expression syntax.
//    /// Returns a simplified type name string or nil if inference fails.
//    private func inferTypeName(from expression: ExprSyntax) -> String? {
//        if let funcCall = expression.as(FunctionCallExprSyntax.self) {
//            // Handles SomeType(...) or SomeModule.SomeType(...)
//            return inferTypeName(from: funcCall.calledExpression) // Recurse on the expression being called
//        } else if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
//            // Handles variable.method(...) or variable.property or EnumType.case
//            // We are interested in the type of the base, e.g. "EnumType" from EnumType.case
//            // If base is nil, it's implicit self or static member access like ".zero" - hard to infer type here.
//            if let base = memberAccess.base {
//                return inferTypeName(from: base) // Recurse on the base
//            } else {
//                // Attempt to get type from the member name if it's a static member/enum case? Heuristic.
//                // e.g., ".shared" -> could be anything. Need context.
//                // Let's return nil for implicit base for now.
//                return nil
//            }
//        } else if let identifier = expression.as(DeclReferenceExprSyntax.self) {
//            // Handles SomeType (e.g., in SomeType.init(...)) or variable names
//            let name = identifier.baseName.text
//            // Simple heuristic: If it starts with uppercase, assume it's a type name.
//            if name.first?.isUppercase == true {
//                return name
//            }
//        }
//        //        else if let explicitMember = expression.as(ExplicitMemberExprSyntax.self) {
//        //            // Handles .case(...) or .staticMember(...)
//        //            // Try to infer from base type if possible
//        //            if let base = explicitMember.base {
//        //                return inferTypeName(from: base)
//        //            } else {
//        //                // e.g. ".shared" called directly, cannot infer base type easily
//        //                return nil
//        //            }
//        //        }
//
//        // Fallback
//        return nil
//    }
//
//    // TODO: These should be identical to the ones in SwiftSyntaxVisitor or refactored into a common utility. For now, duplicate them.
//    private func extractTypeNames(from typeString: String?) -> Set<String> {
//        guard let cleaned = typeString?.trimmingCharacters(in: .whitespacesAndNewlines) else {
//            return []
//        }
//
//        let baseTypes = cleaned
//            .replacingOccurrences(of: "?", with: "")
//            .replacingOccurrences(of: "!", with: "")
//            .replacingOccurrences(of: "[", with: "")
//            .replacingOccurrences(of: "]", with: "")
//            .replacingOccurrences(of: ":", with: "")
//            .components(separatedBy: CharacterSet.alphanumerics.inverted)
//            .filter { !$0.isEmpty && $0.first?.isUppercase == true }
//
//        // TODO: Add common lowercase types like 'any', 'some' if needed
//
//        return Set(baseTypes)
//    }
//
//    private func extractModifiers(from modifierList: DeclModifierListSyntax?) -> [SwiftModifier] {
//        var modifiers: [SwiftModifier] = []
//        guard let modifierList = modifierList else { return modifiers }
//        for modifier in modifierList {
//            if let swiftModifier = SwiftModifier(rawValue: modifier.name.text) {
//                modifiers.append(swiftModifier)
//            }
//        }
//        return modifiers
//    }
//
//    private func extractAnnotations(from attributeList: AttributeListSyntax?) -> [SwiftAnnotation] {
//        var annotations: [SwiftAnnotation] = []
//        guard let attributeList = attributeList else { return annotations }
//
//        for attributeElement in attributeList {
//            // Attributes can be wrapped in #if blocks, handle AttributeSyntax directly
//            guard let attribute = attributeElement.as(AttributeSyntax.self) else {
//                // Skip if it's not a simple attribute (e.g., inside #if)
//                continue
//            }
//
//            let name = attribute.attributeName.trimmedDescription
//            var arguments: [String: String] = [:]
//
//            // Handle different argument syntaxes using the enum cases of AttributeSyntax.Arguments
//            if let args = attribute.arguments {
//                switch args {
//                case .argumentList(let tupleExprElements):
//                    // This handles cases like @MyAttribute(label: value, value2, label3: value3)
//                    for element in tupleExprElements {
//                        let label = element.label?.text // Label if present (e.g., "deprecated:")
//                        let value = element.expression.trimmedDescription // The argument value description
//
//                        // Determine the key for the arguments dictionary
//                        // Use label if it exists, otherwise use "_" for unnamed/positional args
//                        // Note: Multiple unnamed args will overwrite the "_" key here.
//                        // A list might be better for unnamed args if order/multiplicity matters.
//                        let key = label ?? "_"
//
//                        arguments[key] = value
//                    }
//                case .string(let stringLiteralExprSyntax):
//                    // Handles hypothetical @Attribute("someString") syntax if ever used
//                    // This case seems less common for typical attributes.
//                    arguments["_"] = stringLiteralExprSyntax.segments.trimmedDescription
//                case .availability(let availabilityArgumentListSyntax):
//                    // Handles @available(*, deprecated: "message", ...) where the elements
//                    // contain AvailabilityArgumentSyntax nodes.
//                    for syntax in availabilityArgumentListSyntax {
//                        let argument = Syntax(syntax.argument)
//                        if argument.is(PlatformVersionSyntax.self) {
//                            let version = argument.cast(PlatformVersionSyntax.self)
//                            arguments[version.platform.text] = version.version?.trimmedDescription
//                        }
//                    }
//                default:
//                    print("Unhandled attribute argument type: \(args.syntaxNodeType) for attribute \(name)")
//                }
//            }
//            annotations.append(SwiftAnnotation(name: name, arguments: arguments))
//        }
//        return annotations
//    }
//
//    private func extractParameters(from parameterList: FunctionParameterListSyntax) -> [SwiftParameterDeclaration] {
//        return parameterList.map { parameter in
//            let name = parameter.secondName?.text ?? parameter.firstName.text
//            let type = parameter.type.trimmedDescription
//            let defaultValue = parameter.defaultValue?.value.trimmedDescription
//            return SwiftParameterDeclaration(name: name, type: type, defaultValue: defaultValue)
//        }
//    }
//
//    private func extractReturnType(from output: ReturnClauseSyntax?) -> String? {
//        return output?.type.trimmedDescription
//    }
//}
//
//extension SyntaxProtocol {
//    var trimmedDescription: String {
//        return description.trimmingCharacters(in: .whitespacesAndNewlines)
//    }
//}
//
//// MARK: - Dependency Checking API
//
//extension Collection where Element == SwiftDependency {
//    public func containsDependency(name: String, kind: DependencyKind? = nil) -> Bool {
//        return self.contains { dependency in
//            let nameMatch = dependency.name == name
//            let kindMatch = (kind == nil) || (dependency.kind == kind)
//            return nameMatch && kindMatch
//        }
//    }
//
//    public func containsDependency(kind: DependencyKind) -> Bool {
//        return self.contains { $0.kind == kind }
//    }
//}
//
//// MARK: - Enhanced Filtering API
//
//extension Collection where Element: SwiftDeclaration {
//
//    // MARK: - Name Filtering
//
//    /// Filter declarations by name suffix
//    public func withNameSuffix(_ suffix: String) -> [Element] {
//        return self.filter { $0.name.hasSuffix(suffix) }
//
//    }
//
//    /// Filter declarations by name prefix
//    public func withNamePrefix(_ prefix: String) -> [Element] {
//        return self.filter { $0.name.hasPrefix(prefix) }
//    }
//
//    /// Filter declarations by containing name
//    public func withNameContaining(_ substring: String) -> [Element] {
//        return self.filter { $0.name.contains(substring) }
//    }
//
//    /// Filter declarations by name matching regex
//    public func withNameMatching(_ pattern: String) -> [Element] {
//        do {
//            let regex = try Regex(pattern)
//            return self.filter { $0.name.contains(regex) }
//        } catch {
//            print("Invalid regex pattern: \(pattern) - \(error)")
//            return []
//        }
//    }
//
//    /// Filter declarations by exact name
//    public func withName(_ name: String) -> [Element] {
//        return self.filter { $0.name == name }
//    }
//
//    /// Filter declarations by names in the provided array
//    public func withNames(_ names: [String]) -> [Element] {
//        return self.filter { names.contains($0.name) }
//    }
//
//    // MARK: - Modifier Filtering
//
//    /// Filter declarations by having a specific modifier
//    public func withModifier(_ modifier: SwiftModifier) -> [Element] {
//        return self.filter { $0.hasModifier(modifier) }
//    }
//
//    /// Filter declarations by having any of the specified modifiers
//    public func withAnyModifier(_ modifiers: SwiftModifier...) -> [Element] {
//        return self.filter { declaration in
//            modifiers.contains { declaration.hasModifier($0) }
//        }
//    }
//
//    /// Filter declarations by having all of the specified modifiers
//    public func withAllModifiers(_ modifiers: SwiftModifier...) -> [Element] {
//        return self.filter { declaration in
//            modifiers.allSatisfy { declaration.hasModifier($0) }
//        }
//    }
//
//    /// Filter declarations by not having a specific modifier
//    public func withoutModifier(_ modifier: SwiftModifier) -> [Element] {
//        return self.filter { !$0.hasModifier(modifier) }
//    }
//
//    /// Filter declarations by not having any of the specified modifiers
//    public func withoutAnyModifier(_ modifiers: SwiftModifier...) -> [Element] {
//        return self.filter { declaration in
//            !modifiers.contains { declaration.hasModifier($0) }
//        }
//    }
//
//    // MARK: - Annotation Filtering
//
//    /// Filter declarations by having a specific annotation
//    public func withAnnotation(named name: String) -> [Element] {
//        return self.filter { $0.hasAnnotation(named: name) }
//    }
//
//    /// Filter declarations by having any of the specified annotations
//    public func withAnyAnnotation(named names: String...) -> [Element] {
//        return self.filter { declaration in
//            names.contains { declaration.hasAnnotation(named: $0) }
//        }
//    }
//
//    /// Filter declarations by having all of the specified annotations
//    public func withAllAnnotations(named names: String...) -> [Element] {
//        return self.filter { declaration in
//            names.allSatisfy { declaration.hasAnnotation(named: $0) }
//        }
//    }
//
//    /// Filter declarations by not having a specific annotation
//    public func withoutAnnotation(named name: String) -> [Element] {
//        return self.filter { !$0.hasAnnotation(named: name) }
//    }
//
//    // MARK: - Location Filtering
//
//    /// Filter declarations by residing in a specific file
//    public func inFile(_ filePath: String) -> [Element] {
//        return self.filter { $0.filePath == filePath }
//    }
//
//    /// Filter declarations by residing in a file whose path contains the given string
//    public func inFilePathContaining(_ substring: String) -> [Element] {
//        return self.filter { $0.filePath.contains(substring) }
//    }
//
//    /// Filter declarations by residing in a package matching the pattern
//    public func inPackage(_ packagePattern: String) -> [Element] {
//        return self.filter { $0.resideInPackage(packagePattern) }
//    }
//
//    // MARK: - Dependency Filtering
//
//    /// Filter declarations that depend on a specific type
//    public func dependingOn(type: String) -> [Element] {
//        return self.filter { declaration in
//            declaration.dependencies.contains { $0.name == type }
//        }
//    }
//
//    /// Filter declarations that depend on a specific module via imports
//    public func dependingOnModule(_ moduleName: String) -> [Element] {
//        return self.filter { declaration in
//            declaration.dependencies.contains { $0.name == moduleName && $0.kind == .import }
//        }
//    }
//
//    /// Filter declarations that have any type dependency
//    public func havingDependencies() -> [Element] {
//        return self.filter { !$0.dependencies.isEmpty }
//    }
//
//    // MARK: - Combined Filtering
//
//    /// Allows for combining multiple filters with AND logic
//    public func and(_ predicate: @escaping (Element) -> Bool) -> [Element] {
//        return self.filter(predicate)
//    }
//
//    /// Apply a custom filter
//    public func matching(_ predicate: @escaping (Element) -> Bool) -> [Element] {
//        return self.filter(predicate)
//    }
//}
//
//// MARK: - Class-Specific Filtering
//
//extension Collection where Element == SwiftClassDeclaration {
//    /// Filter classes that extend a specific superclass
//    public func extending(class superClassName: String) -> [Element] {
//        return self.filter { $0.extends(class: superClassName) }
//    }
//
//    /// Filter classes that implement a specific protocol
//    public func implementing(protocol protocolName: String) -> [Element] {
//        return self.filter { $0.implements(protocol: protocolName) }
//    }
//
//    /// Filter classes that implement any of the specified protocols
//    public func implementingAny(protocols protocolNames: String...) -> [Element] {
//        return self.filter { classDecl in
//            protocolNames.contains { classDecl.implements(protocol: $0) }
//        }
//    }
//
//    /// Filter classes that implement all of the specified protocols
//    public func implementingAll(protocols protocolNames: String...) -> [Element] {
//        return self.filter { classDecl in
//            protocolNames.allSatisfy { classDecl.implements(protocol: $0) }
//        }
//    }
//
//    /// Filter classes that have a specific method
//    public func havingMethod(named methodName: String) -> [Element] {
//        return self.filter { $0.hasMethod(named: methodName) }
//    }
//
//    /// Filter classes that have a specific property
//    public func havingProperty(named propertyName: String) -> [Element] {
//        return self.filter { $0.hasProperty(named: propertyName) }
//    }
//
//    /// Filter classes that are subclasses (not final)
//    public func subclassable() -> [Element] {
//        return self.filter { !$0.hasModifier(.final) }
//    }
//
//    /// Filter final classes
//    public func final() -> [Element] {
//        return self.filter { $0.hasModifier(.final) }
//    }
//}
//
//// MARK: - Struct-Specific Filtering
//
//extension Collection where Element == SwiftStructDeclaration {
//    /// Filter structs that implement a specific protocol
//    public func implementing(protocol protocolName: String) -> [Element] {
//        return self.filter { $0.implements(protocol: protocolName) }
//    }
//
//    /// Filter structs that implement any of the specified protocols
//    public func implementingAny(protocols protocolNames: String...) -> [Element] {
//        return self.filter { structDecl in
//            protocolNames.contains { structDecl.implements(protocol: $0) }
//        }
//    }
//
//    /// Filter structs that implement all of the specified protocols
//    public func implementingAll(protocols protocolNames: String...) -> [Element] {
//        return self.filter { structDecl in
//            protocolNames.allSatisfy { structDecl.implements(protocol: $0) }
//        }
//    }
//
//    /// Filter structs that have a specific method
//    public func havingMethod(named methodName: String) -> [Element] {
//        return self.filter { $0.hasMethod(named: methodName) }
//    }
//
//    /// Filter structs that have a specific property
//    public func havingProperty(named propertyName: String) -> [Element] {
//        return self.filter { $0.hasProperty(named: propertyName) }
//    }
//}
//
//// MARK: - Protocol-Specific Filtering
//
//extension Collection where Element == SwiftProtocolDeclaration {
//    /// Filter protocols that inherit from a specific protocol
//    public func inheriting(protocol protocolName: String) -> [Element] {
//        return self.filter { $0.inherits(protocol: protocolName) }
//    }
//
//    /// Filter protocols that require a specific method
//    public func requiringMethod(named methodName: String) -> [Element] {
//        return self.filter { protocolDecl in
//            protocolDecl.methodRequirements.contains { $0.name == methodName }
//        }
//    }
//
//    /// Filter protocols that require a specific property
//    public func requiringProperty(named propertyName: String) -> [Element] {
//        return self.filter { protocolDecl in
//            protocolDecl.propertyRequirements.contains { $0.name == propertyName }
//        }
//    }
//}
//
//// MARK: - Function-Specific Filtering
//
//extension Collection where Element == SwiftFunctionDeclaration {
//    /// Filter functions that return a specific type
//    public func returningType(_ typeName: String) -> [Element] {
//        return self.filter { $0.returnType == typeName }
//    }
//
//    /// Filter functions that return any type (not void)
//    public func returningAnyType() -> [Element] {
//        return self.filter { $0.hasReturnType() }
//    }
//
//    /// Filter functions that return void
//    public func returningVoid() -> [Element] {
//        return self.filter { !$0.hasReturnType() }
//    }
//
//    /// Filter functions that have a specific parameter
//    public func havingParameter(named parameterName: String) -> [Element] {
//        return self.filter { $0.hasParameter(named: parameterName) }
//    }
//
//    /// Filter functions with a specific number of parameters
//    public func withParameterCount(_ count: Int) -> [Element] {
//        return self.filter { $0.parameters.count == count }
//    }
//
//    /// Filter functions with at least a certain number of parameters
//    public func withMinParameterCount(_ minCount: Int) -> [Element] {
//        return self.filter { $0.parameters.count >= minCount }
//    }
//
//    /// Filter async functions
//    public func async() -> [Element] {
//        // We'd need to extend SwiftFunctionDeclaration to have an isAsync property
//        // This is a simplified implementation
//        return self.filter { function in
//            function.modifiers.contains { $0.rawValue == "async" }
//        }
//    }
//
//    /// Filter throwing functions
//    public func throwing() -> [Element] {
//        // We'd need to extend SwiftFunctionDeclaration to have a throws property
//        // This is a simplified implementation
//        return self.filter { function in
//            function.modifiers.contains { $0.rawValue == "throws" }
//        }
//    }
//}
//
//// MARK: - Property-Specific Filtering
//
//extension Collection where Element == SwiftPropertyDeclaration {
//    /// Filter properties of a specific type
//    public func ofType(_ typeName: String) -> [Element] {
//        return self.filter { $0.type == typeName }
//    }
//
//    /// Filter computed properties
//    public func computed() -> [Element] {
//        return self.filter { $0.isComputed }
//    }
//
//    /// Filter stored properties
//    public func stored() -> [Element] {
//        return self.filter { !$0.isComputed }
//    }
//
//    /// Filter properties with default values
//    public func withInitialValue() -> [Element] {
//        return self.filter { $0.initialValue != nil }
//    }
//
//    /// Filter properties without default values
//    public func withoutInitialValue() -> [Element] {
//        return self.filter { $0.initialValue == nil }
//    }
//}
//
//// MARK: - Enum-Specific Filtering
//
//extension Collection where Element == SwiftEnumDeclaration {
//    /// Filter enums that implement a specific protocol
//    public func implementing(protocol protocolName: String) -> [Element] {
//        return self.filter { $0.implements(protocol: protocolName) }
//    }
//
//    /// Filter enums with a specific raw type
//    public func withRawType(_ typeName: String) -> [Element] {
//        return self.filter { $0.rawType == typeName }
//    }
//
//    /// Filter enums that have a specific case
//    public func havingCase(named caseName: String) -> [Element] {
//        return self.filter { enumDecl in
//            enumDecl.cases.contains { $0.name == caseName }
//        }
//    }
//
//    /// Filter enums with associated values
//    public func withAssociatedValues() -> [Element] {
//        return self.filter { enumDecl in
//            enumDecl.cases.contains { $0.associatedValues != nil && !($0.associatedValues?.isEmpty ?? true) }
//        }
//    }
//
//    /// Filter enums with raw values
//    public func withRawValues() -> [Element] {
//        return self.filter { enumDecl in
//            enumDecl.cases.contains { $0.rawValue != nil }
//        }
//    }
//}
//
//// MARK: - Import-Specific Filtering
//
//extension Collection where Element == SwiftImportDeclaration {
//    /// Filter imports by module name
//    public func ofModule(_ moduleName: String) -> [Element] {
//        return self.filter { $0.name == moduleName }
//    }
//
//    /// Filter imports by import kind
//    public func ofKind(_ kind: SwiftImportDeclaration.ImportKind) -> [Element] {
//        return self.filter { $0.kind == kind }
//    }
//
//    /// Filter imports that include a specific type
//    public func includingType(_ typeName: String) -> [Element] {
//        return self.filter { $0.includesType(named: typeName) }
//    }
//
//    /// Filter imports from Apple frameworks
//    public func fromAppleFrameworks() -> [Element] {
//        let appleFrameworks = [
//            "UIKit", "SwiftUI", "Foundation", "CoreData", "CoreGraphics",
//            "CoreLocation", "MapKit", "AVFoundation", "CoreBluetooth",
//            "CoreImage", "CoreML", "CloudKit", "GameKit", "HealthKit",
//            "HomeKit", "ARKit", "SceneKit", "SpriteKit", "WatchKit",
//            "WebKit", "StoreKit", "SafariServices", "PhotosUI", "Network",
//            "Metal", "MetalKit", "MetricKit", "ModelIO", "MultipeerConnectivity",
//            "GameController", "GameplayKit", "EventKit", "ExternalAccessory",
//            "CoreMotion", "CoreMedia", "CoreAudio", "CoreAnimation"
//        ]
//
//        return self.filter { appleFrameworks.contains($0.name) }
//    }
//
//    /// Filter imports from third-party libraries (non-Apple frameworks)
//    public func fromThirdPartyLibraries() -> [Element] {
//        let appleFrameworks = [
//            "UIKit", "SwiftUI", "Foundation", "CoreData", "CoreGraphics",
//            "CoreLocation", "MapKit", "AVFoundation", "CoreBluetooth",
//            "CoreImage", "CoreML", "CloudKit", "GameKit", "HealthKit",
//            "HomeKit", "ARKit", "SceneKit", "SpriteKit", "WatchKit",
//            "WebKit", "StoreKit", "SafariServices", "PhotosUI", "Network",
//            "Metal", "MetalKit", "MetricKit", "ModelIO", "MultipeerConnectivity",
//            "GameController", "GameplayKit", "EventKit", "ExternalAccessory",
//            "CoreMotion", "CoreMedia", "CoreAudio", "CoreAnimation"
//        ]
//
//        // Also consider standard library/Swift modules as not third-party
//        let swiftModules = ["Swift", "Combine", "Dispatch", "XCTest"]
//        let allInternalModules = appleFrameworks + swiftModules
//
//        return self.filter { !allInternalModules.contains($0.name) }
//    }
//
//    /// Filter imports with submodules
//    public func withSubmodules() -> [Element] {
//        return self.filter { !$0.submodules.isEmpty }
//    }
//}
//
///// Base protocol for architecture rules
//public protocol ArchitectureRule {
//    var ruleDescription: String { get }
//    var violations: [ArchitectureViolation] { get set }
//
//    func check(context: inout ArchitectureRuleContext) -> Bool
//}
//
///// Context provided to architecture rules for checking
//public struct ArchitectureRuleContext {
//    let scope: Conformant
//    let declarations: [any SwiftDeclaration]
//    let layers: [Layer]
//
//    private var typeToLayerCache: [String: Layer?] = [:]
//
//    init(scope: Conformant, declarations: [any SwiftDeclaration], layers: [Layer]) {
//        self.scope = scope
//        self.declarations = declarations
//        self.layers = layers
//    }
//
//    /// Find all declarations in a specific layer
//    func declarationsInLayer(_ layer: Layer) -> [any SwiftDeclaration] {
//        return declarations.filter { layer.resideIn($0) }
//    }
//
//    /// Determine which layer a declaration belongs to
//    func layerContaining(declaration: any SwiftDeclaration) -> Layer? {
//        for layer in layers {
//            if layer.resideIn(declaration) {
//                return layer
//            }
//        }
//        return nil
//    }
//
//    /// Determine which layer a dependency belongs to
//    mutating func layerContaining(dependency: SwiftDependency) -> Layer? {
//        if let cachedLayer = typeToLayerCache[dependency.name] {
//            return cachedLayer
//        }
//
//        if dependency.kind == .import {
//            for layer in layers {
//                if layer.containsDependency(dependency) {
//                    typeToLayerCache[dependency.name] = layer
//                    return layer
//                }
//            }
//
//            typeToLayerCache[dependency.name] = nil
//
//            return nil
//        }
//
//        let matchingDeclarations = declarations.filter {
//            $0.name == dependency.name
//        }
//
//        for declaration in matchingDeclarations {
//            if let layer = layerContaining(declaration: declaration) {
//                typeToLayerCache[dependency.name] = layer
//                return layer
//            }
//        }
//
//        typeToLayerCache[dependency.name] = nil
//        return nil
//    }
//
//    /// Check if a dependency is from one layer to another
//    mutating func isDependency(from sourceLayer: Layer, to targetLayer: Layer, dependency: SwiftDependency) -> Bool {
//        if dependency.kind == .import && targetLayer.containsDependency(dependency) {
//            return true
//        }
//
//        if let dependencyLayer = layerContaining(dependency: dependency) {
//            return dependencyLayer.name == targetLayer.name
//        }
//
//        return false
//    }
//}
//
///// Container for architecture rules
//public class ArchitectureRules {
//    var rules: [ArchitectureRule] = []
//    var layers: [String: Layer] = [:]
//
//    /// Add a rule to the architecture rules
//    public func add(_ rule: ArchitectureRule) {
//        rules.append(rule)
//    }
//
//    /// Define a layer in the architecture
//    public func defineLayer(_ layer: Layer) {
//        layers[layer.name] = layer
//    }
//
//    /// Get a layer by name
//    public func layer(_ name: String) -> Layer? {
//        return layers[name]
//    }
//}
//
///// Represents a violation of an architecture rule
//public struct ArchitectureViolation {
//    let sourceDeclaration: any SwiftDeclaration
//    let dependency: SwiftDependency
//    let ruleDescription: String
//    let detail: String
//}
//
///// Rule that enforces a layer doesn't depend on any other layer
//public class DependsOnNothingRule: ArchitectureRule {
//    let source: Layer
//    public var violations: [ArchitectureViolation] = []
//
//    public var ruleDescription: String {
//        return "Layer '\(source.name)' should not depend on any other layer"
//    }
//
//    init(source: Layer) {
//        self.source = source
//    }
//
//    public func check(context: inout ArchitectureRuleContext) -> Bool {
//        violations = []
//
//        let sourceDeclarations = context.declarationsInLayer(source)
//
//        for declaration in sourceDeclarations {
//            for dependency in declaration.dependencies {
//                if dependency.kind != .typeUsage && dependency.kind != .inheritance && dependency.kind != .conformance {
//                    continue
//                }
//
//                if !source.resideIn(declaration) {
//                    violations.append(ArchitectureViolation(
//                        sourceDeclaration: declaration,
//                        dependency: dependency,
//                        ruleDescription: ruleDescription,
//                        detail: "Depends on external type '\(dependency.name)'"
//                    ))
//                }
//            }
//        }
//
//        return violations.isEmpty
//    }
//}
//
///// Rule that enforces one layer depends on another
//public class DependsOnRule: ArchitectureRule {
//    let source: Layer
//    let target: Layer
//    public var violations: [ArchitectureViolation] = []
//
//    public var ruleDescription: String {
//        return "Layer '\(source.name)' should depend on layer '\(target.name)'"
//    }
//
//    init(source: Layer, target: Layer) {
//        self.source = source
//        self.target = target
//    }
//
//    public func check(context: inout ArchitectureRuleContext) -> Bool {
//        violations = []
//
//        let sourceDeclarations = context.declarationsInLayer(source)
//
//        for declaration in sourceDeclarations {
//            for dependency in declaration.dependencies {
//                if dependency.kind != .typeUsage && dependency.kind != .inheritance && dependency.kind != .conformance {
//                    continue
//                }
//
//                if let dependencyLayer = context.layerContaining(dependency: dependency) {
//                    if dependencyLayer.name != target.name {
//                        violations.append(ArchitectureViolation(
//                            sourceDeclaration: declaration,
//                            dependency: dependency,
//                            ruleDescription: ruleDescription,
//                            detail: "Uses '\(dependency.name)' from layer '\(dependencyLayer.name)' instead of '\(target.name)'"
//                        ))
//                    }
//                }
//            }
//        }
//
//        return violations.isEmpty
//    }
//}
//
///// Represents a layer in the architecture
//public struct Layer {
//    let name: String
//    let resideIn: (any SwiftDeclaration) -> Bool
//
//    // A set of module names that are considered part of this layer
//    // Used for import-based dependency checking
//    private let modulesInLayer: Set<String>
//
//    /// Initialize a Layer with a name and a regex pattern to match file paths
//    public init(name: String, identifierPattern: String) {
//        self.name = name
//        self.modulesInLayer = [] // No specific modules defined
//        self.resideIn = { declaration in
//            let filePath = declaration.filePath
//            let regexPattern = identifierPattern.replacingOccurrences(of: "..", with: ".*")
//            do {
//                let regex = try Regex(regexPattern)
//                return filePath.contains(regex)
//            } catch {
//                print("Invalid regex pattern in Layer definition: \(regexPattern) - \(error)")
//                return false
//            }
//        }
//    }
//
//    /// Initialize a Layer with a name and a directory path
//    public init(name: String, directory: String) {
//        self.name = name
//        self.modulesInLayer = []
//        self.resideIn = { declaration in
//            let targetDir = directory
//                .replacingOccurrences(of: "\\", with: "/")
//                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
//
//            let declPath = declaration.filePath
//                .replacingOccurrences(of: "\\", with: "/")
//
//            guard !targetDir.isEmpty else { return false }
//
//            let pattern1 = "/\(targetDir)/"
//
//            return declPath.contains(pattern1)
//
//            // Alternative/More Robust (might be needed if paths are tricky):
//            // Use URL path components
//            // let declURL = URL(fileURLWithPath: declaration.filePath)
//            // return declURL.pathComponents.contains(targetDir)
//        }
//    }
//
//    /// Initialize a Layer with a name and a module name
//    public init(name: String, module: String) {
//        self.name = name
//        self.modulesInLayer = [module]
//        self.resideIn = { declaration in
//            // Use URL path components for more robust checking
//            let components = URL(fileURLWithPath: declaration.filePath).pathComponents
//            let result = components.contains(module) // Check if module name exists as a path component
//             print("DEBUG resideIn(Module): Layer='\(name)' Module='\(module)' DeclPath='\(declaration.filePath)' Components='\(components)' Contains=\(result)")
//            return result
//        }
//    }
//
//    /// Initialize a Layer with a name and multiple module names
//    public init(name: String, modules: [String]) {
//         self.name = name
//         self.modulesInLayer = Set(modules)
//         self.resideIn = { declaration in
//             let components = URL(fileURLWithPath: declaration.filePath).pathComponents
//             // Check if any specified module name exists as a path component
//             let result = modules.contains { module in
//                 components.contains(module)
//             }
//             print("DEBUG resideIn(Modules): Layer='\(name)' Modules='\(modules)' DeclPath='\(declaration.filePath)' Components='\(components)' Contains=\(result)")
//             return result
//         }
//     }
//
//    /// Initialize a Layer with a name and a custom predicate
//    public init(name: String, predicate: @escaping (any SwiftDeclaration) -> Bool) {
//        self.name = name
//        self.modulesInLayer = [] // No specific modules defined
//        self.resideIn = predicate
//    }
//
//    /// Initialize a Layer with a name, modules, and a custom predicate
//    public init(name: String, modules: [String], predicate: @escaping (any SwiftDeclaration) -> Bool) {
//        self.name = name
//        self.modulesInLayer = Set(modules)
//        self.resideIn = predicate
//    }
//
//    /// Check if a dependency points to this layer based on module imports
//    public func containsDependency(_ dependency: SwiftDependency) -> Bool {
//        guard dependency.kind == .import else { return false }
//        return modulesInLayer.contains(dependency.name)
//    }
//
//    /// Create a rule specifying this layer should depend on another layer
//    public func dependsOn(_ layer: Layer) -> ArchitectureRule {
//        return DependsOnRule(source: self, target: layer)
//    }
//
//    /// Create a rule specifying this layer should not depend on any other layer
//    public func dependsOnNothing() -> ArchitectureRule {
//        return DependsOnNothingRule(source: self)
//    }
//
//    /// Create a rule specifying this layer can only depend on specified layers
//    public func onlyDependsOn(_ layers: Layer...) -> ArchitectureRule {
//        return OnlyDependsOnRule(source: self, targetLayers: layers)
//    }
//
//    /// Create a rule specifying this layer should not depend on specified layers
//    public func mustNotDependOn(_ layers: Layer...) -> ArchitectureRule {
//        return MustNotDependOnRule(source: self, forbiddenLayers: layers)
//    }
//}
//
///// Rule that enforces a layer does not depend on specified layers
//public class MustNotDependOnRule: ArchitectureRule {
//    let source: Layer
//    let forbiddenLayers: [Layer]
//    public var violations: [ArchitectureViolation] = []
//
//    public var ruleDescription: String {
//        let forbiddenNames = forbiddenLayers.map { $0.name }.joined(separator: ", ")
//        return "Layer '\(source.name)' must not depend on: \(forbiddenNames)"
//    }
//
//    init(source: Layer, forbiddenLayers: [Layer]) {
//        self.source = source
//        self.forbiddenLayers = forbiddenLayers
//    }
//
//    public func check(context: inout ArchitectureRuleContext) -> Bool {
//        violations = []
//
//        let sourceDeclarations = context.declarationsInLayer(source)
//
//        for declaration in sourceDeclarations {
//            for dependency in declaration.dependencies {
//                if dependency.kind != .typeUsage && dependency.kind != .inheritance && dependency.kind != .conformance {
//                    continue
//                }
//
//                if let dependencyLayer = context.layerContaining(dependency: dependency) {
//                    if forbiddenLayers.contains(where: { $0.name == dependencyLayer.name }) {
//                        violations.append(ArchitectureViolation(
//                            sourceDeclaration: declaration,
//                            dependency: dependency,
//                            ruleDescription: ruleDescription,
//                            detail: "Depends on forbidden layer '\(dependencyLayer.name)'"
//                        ))
//                    }
//                }
//            }
//        }
//
//        return violations.isEmpty
//    }
//}
//
///// Rule that enforces a layer can only depend on specified layers
//public class OnlyDependsOnRule: ArchitectureRule {
//    let source: Layer
//    let targetLayers: [Layer]
//    public var violations: [ArchitectureViolation] = []
//
//    public var ruleDescription: String {
//        let targetNames = targetLayers.map { $0.name }.joined(separator: ", ")
//        return "Layer '\(source.name)' should only depend on: \(targetNames)"
//    }
//
//    init(source: Layer, targetLayers: [Layer]) {
//        self.source = source
//        self.targetLayers = targetLayers
//    }
//
//    public func check(context: inout ArchitectureRuleContext) -> Bool {
//        violations = []
//
//        let sourceDeclarations = context.declarationsInLayer(source)
//
//        for declaration in sourceDeclarations {
//            for dependency in declaration.dependencies {
//                if dependency.kind != .typeUsage && dependency.kind != .inheritance && dependency.kind != .conformance {
//                    continue
//                }
//
//                if let dependencyLayer = context.layerContaining(dependency: dependency) {
//                    if dependencyLayer.name != source.name && !targetLayers.contains(where: { $0.name == dependencyLayer.name }) {
//                        violations.append(ArchitectureViolation(
//                            sourceDeclaration: declaration,
//                            dependency: dependency,
//                            ruleDescription: ruleDescription,
//                            detail: "Depends on disallowed layer '\(dependencyLayer.name)'"
//                        ))
//                    }
//                }
//            }
//        }
//
//        return violations.isEmpty
//    }
//}
//
///// Extension to add architecture verification to SwiftScope
//extension Conformant {
//    public func assertArchitecture(_ defineRules: (ArchitectureRules) -> Void) -> Bool {
//        let ruleSet = ArchitectureRules()
//        defineRules(ruleSet)
//
//        var context = ArchitectureRuleContext(
//            scope: self,
//            declarations: self.declarations(),
//            layers: Array(ruleSet.layers.values)
//        )
//
//        var allPassed = true
//        for rule in ruleSet.rules {
//            if !rule.check(context: &context) {
//                allPassed = false
//
//                print("Rule Failed: \(rule.ruleDescription)")
//                for violation in rule.violations {
//                    print("  \(violation.detail) in \(violation.sourceDeclaration.name) at \(violation.sourceDeclaration.filePath):\(violation.sourceDeclaration.location.line)")
//                }
//            }
//        }
//        return allPassed
//    }
//}
//
///// Represents a collection of Swift files to analyze
//public struct Conformant {
//    private let swiftFiles: [SwiftFile]
//
//    private init(swiftFiles: [SwiftFile]) {
//        self.swiftFiles = swiftFiles
//    }
//
//    public static func scopeFromProject(_ projectPath: String = FileManager.default.currentDirectoryPath) -> Conformant {
//        let fileManager = FileManager.default
//        let parser = SwiftSyntaxParser()
//        var swiftFiles: [SwiftFile] = []
//
//        // Helper function to recursively scan directories
//        func scanDirectory(_ directoryPath: String) {
//            do {
//                let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
//
//                for item in contents {
//                    let itemPath = (directoryPath as NSString).appendingPathComponent(item)
//                    var isDirectory: ObjCBool = false
//
//                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
//                        if isDirectory.boolValue {
//                            // Skip common directories that shouldn't be analyzed
//                            if !shouldSkipDirectory(item) {
//                                scanDirectory(itemPath)
//                            }
//                        } else if item.hasSuffix(".swift") {
//                            // Parse Swift file and add to scope
//                            do {
//                                let swiftFile = try parser.parseFile(path: itemPath)
//                                swiftFiles.append(swiftFile)
//                            } catch {
//                                print("Error parsing Swift file at \(itemPath): \(error)")
//                            }
//                        }
//                    }
//                }
//            } catch {
//                print("Error scanning directory \(directoryPath): \(error)")
//            }
//        }
//
//        // Start scanning from the project root
//        scanDirectory(projectPath)
//
//        return Conformant(swiftFiles: swiftFiles)
//    }
//
//    private static func shouldSkipDirectory(_ directoryName: String) -> Bool {
//        // Common directories to skip
//        let directoriesToSkip = [
//            ".git",           // Git directory
//            ".build",         // Swift build directory
//            "Pods",           // CocoaPods
//            "Carthage",       // Carthage
//            "DerivedData",    // Xcode derived data
//            ".xcodeproj",     // Xcode project files
//            ".xcworkspace",   // Xcode workspace
//            ".playground",    // Swift playgrounds
//            "node_modules",   // Node.js modules
//            ".github",        // GitHub configuration
//            ".gitlab",        // GitLab configuration
//            "fastlane",       // Fastlane directory
//            "vendor",         // Vendor dependencies
//            "Frameworks",     // Frameworks directory that might contain compiled binaries
//            "Products"        // Products directory
//        ]
//
//        // Skip hidden directories (those starting with .)
//        if directoryName.hasPrefix(".") {
//            return true
//        }
//
//        // Skip directories in the skip list
//        return directoriesToSkip.contains { directoryName.contains($0) }
//    }
//
//    public static func scopeFromDirectory(_ path: String) -> Conformant {
//        let fileManager = FileManager.default
//        let rootURL = URL(fileURLWithPath: path)
//        var swiftFileURLs: [URL] = []
//
//        guard let enumerator = fileManager.enumerator(
//            at: rootURL,
//            includingPropertiesForKeys: nil, // Can add [.isRegularFileKey] for efficiency
//            options: [.skipsHiddenFiles, .skipsPackageDescendants],
//            errorHandler: { url, error -> Bool in
//                print("Directory enumerator error at \(url): \(error)")
//                return true
//            }
//        ) else {
//            print("Error: Could not create directory enumerator for path: \(path)")
//            return Conformant(swiftFiles: [])
//        }
//
//        for case let fileURL as URL in enumerator {
//            if fileURL.pathExtension == "swift" {
//                // Optional: Check if it's a regular file if not done via keys
//                // var isRegularFile: ObjCBool = false
//                // if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isRegularFile) && isRegularFile.boolValue {
//                swiftFileURLs.append(fileURL)
//                // }
//            }
//        }
//
//        if swiftFileURLs.isEmpty {
//            print("Warning: No Swift files found recursively in directory: \(path)")
//            if !fileManager.fileExists(atPath: path) {
//                print("Error: Directory path does not exist: \(path)")
//            }
//            return Conformant(swiftFiles: [])
//        }
//
//        let parser = SwiftSyntaxParser()
//        let swiftFiles = swiftFileURLs.compactMap { url -> SwiftFile? in
//            do {
//                return try parser.parseFile(path: url.path)
//            } catch {
//                print("Error parsing file \(url.path): \(error)")
//                return nil
//            }
//        }
//
//        return Conformant(swiftFiles: swiftFiles)
//    }
//
//    public static func scopeFromFile(path: String) -> Conformant {
//        do {
//            let parser = SwiftSyntaxParser()
//            let file = try parser.parseFile(path: path)
//            return Conformant(swiftFiles: [file])
//        } catch {
//            print("Error parsing file \(path): \(error)")
//            return Conformant(swiftFiles: [])
//        }
//    }
//
//    // Query methods
//
//    public func files() -> [SwiftFile] {
//        return swiftFiles
//    }
//
//    /// Returns all import declarations in the scope
//    public func imports() -> [SwiftImportDeclaration] {
//        return files().flatMap { $0.imports }
//    }
//
//    /// Returns all imports of a specific module
//    public func importsOf(_ module: String) -> [SwiftImportDeclaration] {
//        return imports().filter { $0.isImportOf(module) }
//    }
//
//    /// Checks if any file in the scope imports the specified module
//    public func hasImport(of module: String) -> Bool {
//        return imports().contains { $0.isImportOf(module) }
//    }
//
//    public func classes() -> [SwiftClassDeclaration] {
//        return files().flatMap { $0.classes }
//    }
//
//    public func structs() -> [SwiftStructDeclaration] {
//        return files().flatMap { $0.structs }
//    }
//
//    public func protocols() -> [SwiftProtocolDeclaration] {
//        return files().flatMap { $0.protocols }
//    }
//
//    public func extensions() -> [SwiftExtensionDeclaration] {
//        return files().flatMap { $0.extensions }
//    }
//
//    public func functions() -> [SwiftFunctionDeclaration] {
//        return files().flatMap { $0.functions }
//    }
//
//    public func properties() -> [SwiftPropertyDeclaration] {
//        return files().flatMap { $0.properties }
//    }
//
//    public func enums() -> [SwiftEnumDeclaration] {
//        return files().flatMap { $0.enums }
//    }
//
////    declaration → import-declaration
////    declaration → constant-declaration // missing
////    declaration → variable-declaration
////    declaration → typealias-declaration // missing
////    declaration → function-declaration
////    declaration → enum-declaration
////    declaration → struct-declaration
////    declaration → class-declaration
////    declaration → actor-declaration // missing
////    declaration → protocol-declaration
////    declaration → initializer-declaration // missing
////    declaration → deinitializer-declaration // missing
////    declaration → extension-declaration
////    declaration → subscript-declaration // missing
////    declaration → macro-declaration // missing
////    declaration → operator-declaration // missing
////    declaration → precedence-group-declaration // missing
//
//    public func declarations() -> [AnySwiftDeclaration] {
//        var declarations: [AnySwiftDeclaration] = []
////        declarations.append(contentsOf: imports().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: functions().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: properties().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
//        return declarations
//    }
//
//    public func types() -> [AnySwiftDeclaration] {
//        var declarations: [AnySwiftDeclaration] = []
//        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
//        return declarations
//    }
//
//    public func classesAndExtensions() -> [AnySwiftDeclaration] {
//        var declarations: [AnySwiftDeclaration] = []
//        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
//        return declarations
//    }
//
//    public func structsAndExtensions() -> [AnySwiftDeclaration] {
//        var declarations: [AnySwiftDeclaration] = []
//        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
//        return declarations
//    }
//
//    public func enumsAndExtensions() -> [AnySwiftDeclaration] {
//        var declarations: [AnySwiftDeclaration] = []
//        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
//        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
//        return declarations
//    }
//}
//
///// Extension to add assertion methods to collections of declarations
//extension Collection where Element: SwiftDeclaration {
//    /// Assert that all elements match the given predicate
//    public func assertTrue(predicate: (Element) -> Bool) -> Bool {
//        return self.allSatisfy(predicate)
//    }
//
//    /// Assert that all elements do not match the given predicate
//    public func assertFalse(predicate: (Element) -> Bool) -> Bool {
//        return self.allSatisfy { !predicate($0) }
//    }
//
//    /// Assert that at least one element matches the given predicate
//    public func assertAny(predicate: (Element) -> Bool) -> Bool {
//        return self.contains(where: predicate)
//    }
//
//    /// Assert that no elements match the given predicate
//    public func assertNone(predicate: (Element) -> Bool) -> Bool {
//        return !self.contains(where: predicate)
//    }
//}
//
///// Wraps an architecture rule with freezing functionality
//public class FreezingArchRule: ArchitectureRule {
//    private var wrappedRule: ArchitectureRule
//    private let violationStore: ViolationStore
//    private let lineMatcher: ViolationLineMatcher
//
//    public var ruleDescription: String {
//        return "Freezing: " + wrappedRule.ruleDescription
//    }
//
//    public var violations: [ArchitectureViolation] {
//        get { return wrappedRule.violations }
//        set { wrappedRule.violations = newValue }
//    }
//
//    /// Creates a new freezing architecture rule
//    /// - Parameters:
//    ///   - rule: The rule to wrap
//    ///   - violationStore: The store for violations
//    ///   - lineMatcher: The matcher for comparing violations
//    public init(rule: ArchitectureRule,
//                violationStore: ViolationStore,
//                lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) {
//        self.wrappedRule = rule
//        self.violationStore = violationStore
//        self.lineMatcher = lineMatcher
//    }
//
//    public func check(context: inout ArchitectureRuleContext) -> Bool {
//        // Check the wrapped rule first
//        let ruleResult = wrappedRule.check(context: &context)
//
//        // If the rule passes and there are no violations, there's nothing more to do
//        if ruleResult && wrappedRule.violations.isEmpty {
//            // The rule passed cleanly - clear any stored violations since all issues are fixed
//            violationStore.saveViolations([])
//            return true
//        }
//
//        // Load stored violations
//        let storedViolations = violationStore.loadViolations()
//
//        // Filter the current violations to only include new ones
//        var newViolations: [ArchitectureViolation] = []
//        var updatedStoredViolations: [StoredViolation] = []
//
//        // Keep track of which stored violations are still relevant
//        var matchedStoredViolationIndices = Set<Int>()
//
//        // Find new violations (those not in stored violations)
//        for currentViolation in wrappedRule.violations {
//            // Check if this violation is already stored
//            var isNewViolation = true
//
//            for (index, storedViolation) in storedViolations.enumerated() {
//                if lineMatcher.matches(stored: storedViolation, actual: currentViolation) {
//                    isNewViolation = false
//                    matchedStoredViolationIndices.insert(index)
//                    break
//                }
//            }
//
//            if isNewViolation {
//                newViolations.append(currentViolation)
//            }
//        }
//
//        // Update stored violations to keep only those that still exist
//        for (index, storedViolation) in storedViolations.enumerated() {
//            if matchedStoredViolationIndices.contains(index) {
//                updatedStoredViolations.append(storedViolation)
//            }
//        }
//
//        // Add new violations to the stored list
//        for newViolation in newViolations {
//            updatedStoredViolations.append(StoredViolation(from: newViolation))
//        }
//
//        // Save the updated violations list
//        let uniqueViolations = Array(Set(updatedStoredViolations))
//        violationStore.saveViolations(uniqueViolations)
//
//        // Replace the wrapped rule's violations with only the new ones
//        wrappedRule.violations = newViolations
//
//        // Return success if there are no new violations
//        return newViolations.isEmpty
//    }
//}
//
///// Represents a stored violation for freezing architecture rules
//public struct StoredViolation: Codable, Hashable {
//    /// The source file where the violation occurred
//    public let filePath: String
//
//    /// The line number where the violation occurred
//    public let line: Int
//
//    /// The rule that was violated
//    public let ruleDescription: String
//
//    /// Details about the violation
//    public let detail: String
//
//    /// The declaration name that caused the violation
//    public let declarationName: String
//
//    /// Creates a new stored violation from an architecture violation
//    public init(from violation: ArchitectureViolation) {
//        self.filePath = violation.sourceDeclaration.filePath
//        self.line = violation.sourceDeclaration.location.line
//        self.ruleDescription = violation.ruleDescription
//        self.detail = violation.detail
//        self.declarationName = violation.sourceDeclaration.name
//    }
//
//    /// Creates a new stored violation explicitly
//    public init(filePath: String, line: Int, ruleDescription: String, detail: String, declarationName: String) {
//        self.filePath = filePath
//        self.line = line
//        self.ruleDescription = ruleDescription
//        self.detail = detail
//        self.declarationName = declarationName
//    }
//}
//
//extension ArchitectureRule {
//    /// Creates a freezing version of this rule
//    /// - Parameters:
//    ///   - violationStore: The store for violations
//    ///   - lineMatcher: The matcher for comparing violations
//    /// - Returns: A freezing architecture rule that wraps this rule
//    public func freeze(using violationStore: ViolationStore,
//                       matching lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) -> FreezingArchRule {
//        return FreezingArchRule(rule: self, violationStore: violationStore, lineMatcher: lineMatcher)
//    }
//
//    /// Creates a freezing version of this rule using a file-based violation store
//    /// - Parameter filePath: The path to the JSON file where violations will be stored
//    /// - Returns: A freezing architecture rule that wraps this rule
//    public func freeze(toFile filePath: String) -> FreezingArchRule {
//        let store = FileViolationStore(filePath: filePath)
//        return FreezingArchRule(rule: self, violationStore: store)
//    }
//}
//
//extension ArchitectureRules {
//    /// Adds a freezing version of a rule
//    /// - Parameters:
//    ///   - rule: The rule to wrap
//    ///   - violationStore: The store for violations
//    ///   - lineMatcher: The matcher for comparing violations
//    public func addFreezing(_ rule: ArchitectureRule,
//                            using violationStore: ViolationStore,
//                            matching lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) {
//        add(rule.freeze(using: violationStore, matching: lineMatcher))
//    }
//
//    /// Adds a freezing version of a rule using a file-based violation store
//    /// - Parameters:
//    ///   - rule: The rule to wrap
//    ///   - filePath: The path to the JSON file where violations will be stored
//    public func addFreezing(_ rule: ArchitectureRule, toFile filePath: String) {
//        add(rule.freeze(toFile: filePath))
//    }
//
//    /// Freezes all rules in a specified directory
//    /// - Parameter directory: The directory where violation files will be stored
//    public func freezeAllRules(inDirectory directory: String) {
//        // Ensure the directory exists
//        let fileManager = FileManager.default
//        if !fileManager.fileExists(atPath: directory) {
//            try? fileManager.createDirectory(at: URL(fileURLWithPath: directory),
//                                             withIntermediateDirectories: true)
//        }
//
//        // Replace rules with frozen versions
//        let originalRules = rules
//        rules = []
//
//        for (index, rule) in originalRules.enumerated() {
//            // Generate a filename based on the rule description
//            let sanitizedDesc = rule.ruleDescription
//                .replacingOccurrences(of: " ", with: "_")
//                .replacingOccurrences(of: "/", with: "_")
//                .replacingOccurrences(of: "\\", with: "_")
//                .replacingOccurrences(of: ":", with: "")
//
//            let fileName = "rule_\(index)_\(sanitizedDesc).json"
//            let filePath = (directory as NSString).appendingPathComponent(fileName)
//
//            add(rule.freeze(toFile: filePath))
//        }
//    }
//}
//
///// Protocol for storing and retrieving architecture rule violations
//public protocol ViolationStore {
//    /// Loads the stored violations from the store
//    func loadViolations() -> [StoredViolation]
//
//    /// Saves violations to the store
//    func saveViolations(_ violations: [StoredViolation])
//}
//
///// Implementation of ViolationStore that uses a JSON file
//public class FileViolationStore: ViolationStore {
//    private let filePath: String
//
//    /// Creates a new file-based violation store
//    /// - Parameter filePath: The path to the JSON file where violations will be stored
//    public init(filePath: String) {
//        self.filePath = filePath
//    }
//
//    public func loadViolations() -> [StoredViolation] {
//        guard FileManager.default.fileExists(atPath: filePath) else {
//            return []
//        }
//
//        do {
//            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
//            return try JSONDecoder().decode([StoredViolation].self, from: data)
//        } catch {
//            print("Error loading violations: \(error)")
//            return []
//        }
//    }
//
//    public func saveViolations(_ violations: [StoredViolation]) {
//        do {
//            let data = try JSONEncoder().encode(violations)
//            try data.write(to: URL(fileURLWithPath: filePath))
//        } catch {
//            print("Error saving violations: \(error)")
//        }
//    }
//}
//
///// Implementation of ViolationStore that stores violations in memory
//public class InMemoryViolationStore: ViolationStore {
//    private var violations: [StoredViolation] = []
//
//    public init() {}
//
//    public func loadViolations() -> [StoredViolation] {
//        return violations
//    }
//
//    public func saveViolations(_ violations: [StoredViolation]) {
//        self.violations = violations
//    }
//}
//
///// Protocol for matching stored violations with new violations
//public protocol ViolationLineMatcher {
//    /// Determines if a stored violation matches a new violation
//    func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool
//}
//
///// Default implementation of ViolationLineMatcher that ignores line numbers within the same file/class
//public struct DefaultViolationLineMatcher: ViolationLineMatcher {
//    public init() {}
//
//    public func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool {
//        // Match if same file, same declaration name, and same rule violation
//        return stored.filePath == actual.sourceDeclaration.filePath &&
//        stored.declarationName == actual.sourceDeclaration.name &&
//        stored.ruleDescription == actual.ruleDescription &&
//        stored.detail == actual.detail
//    }
//}
//
///// Line matcher that requires exact line matches
//public struct ExactLineViolationMatcher: ViolationLineMatcher {
//    public init() {}
//
//    public func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool {
//        return stored.filePath == actual.sourceDeclaration.filePath &&
//        stored.line == actual.sourceDeclaration.location.line &&
//        stored.ruleDescription == actual.ruleDescription
//    }
//}
