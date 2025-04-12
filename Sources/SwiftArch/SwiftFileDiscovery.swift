//
//  SwiftFileDiscovery.swift
//  SwiftArch
//
//  Created by Prince Ugwuh on 4/10/25.
//


import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - File Discovery

/// Utility for discovering Swift source files
public struct SwiftFileDiscovery {
    /// Find all Swift files in the given directory path and its subdirectories
    /// - Parameter directoryPath: Path to search for Swift files
    /// - Returns: Array of file URLs for Swift source files
    public static func findSwiftFiles(inDirectory directoryPath: String) throws -> [URL] {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directoryPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw SwiftArchError.directoryNotFound(path: directoryPath)
        }

        var swiftFiles = [URL]()

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }

        return swiftFiles
    }
}

// MARK: - Architecture Model Builder

/// Main class responsible for parsing Swift files and building the architecture model
public class ArchitectureModelBuilder {
    private var modules: [String: SwiftModule] = [:]
    private var dependencies: [Dependency] = []
    private var currentModuleName: String = ""
    private var currentFile: URL?

    public init() {}

    /// Parse Swift files and build the architecture model
    /// - Parameters:
    ///   - directoryPath: Path to the directory containing Swift files
    ///   - moduleName: Name of the module (if not provided, will use the directory name)
    /// - Returns: Constructed SwiftTarget representing the parsed codebase
    public func parseProject(atPath directoryPath: String, moduleName: String? = nil) throws -> SwiftTarget {
        // Determine module name if not provided
        self.currentModuleName = moduleName ?? URL(fileURLWithPath: directoryPath).lastPathComponent

        // Create a module placeholder
        let module = SwiftModule(name: currentModuleName, location: directoryPath)
        modules[currentModuleName] = module

        // Find all Swift files
        let swiftFiles = try SwiftFileDiscovery.findSwiftFiles(inDirectory: directoryPath)

        // Parse each file
        for fileURL in swiftFiles {
            try parseFile(at: fileURL)
        }

        // Resolve references and dependencies
        resolveReferences()

        // Build the final SwiftTarget
        return SwiftTarget(name: currentModuleName, modules: Array(modules.values))
    }

    /// Parse a single Swift file and update the architecture model
    /// - Parameter fileURL: URL of the Swift file to parse
    private func parseFile(at fileURL: URL) throws {
        currentFile = fileURL

        // Read file content
        let fileContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Parse with SwiftSyntax
        let sourceFile = Parser.parse(source: fileContent)

        // Visit the syntax tree with our custom visitor
        let visitor = ArchitectureSyntaxVisitor(
            filePath: fileURL.path,
            moduleName: currentModuleName,
            builder: self
        )
        visitor.walk(sourceFile)
    }

    /// Add a parsed type to the architecture model
    /// - Parameters:
    ///   - type: The SwiftType to add
    ///   - moduleName: The module to which the type belongs
    func addType(_ type: any SwiftType, toModule moduleName: String) {
        // Get or create the module
        var module = modules[moduleName] ?? SwiftModule(
            name: moduleName,
            location: URL(fileURLWithPath: moduleName).path
        )

        // Add the type
        var types = module.types
        types.append(type)

        // Update the module
        module = SwiftModule(
            name: module.name,
            types: types,
            imports: module.imports,
            location: module.location
        )

        modules[moduleName] = module
    }

    /// Add an import statement to the architecture model
    /// - Parameters:
    ///   - importStatement: The import statement to add
    ///   - moduleName: The module that contains this import
    func addImport(_ importStatement: ImportStatement, toModule moduleName: String) {
        // Get or create the module
        var module = modules[moduleName] ?? SwiftModule(
            name: moduleName,
            location: URL(fileURLWithPath: moduleName).path
        )

        // Add the import
        var imports = module.imports
        imports.append(importStatement)

        // Update the module
        module = SwiftModule(
            name: module.name,
            types: module.types,
            imports: imports,
            location: module.location
        )

        modules[moduleName] = module
    }

    /// Add a dependency relationship to the architecture model
    /// - Parameter dependency: The dependency to add
    func addDependency(_ dependency: Dependency) {
        dependencies.append(dependency)
    }

    /// Resolve references between types and build complete dependency graph
    private func resolveReferences() {
        // This would involve more complex logic to:
        // 1. Connect type references to actual types
        // 2. Link methods and properties to their containing types
        // 3. Build a complete dependency graph

        // Simplified implementation for now
    }
}

// MARK: - Syntax Visitor

/// Custom SyntaxVisitor that extracts architectural information from Swift syntax trees
class ArchitectureSyntaxVisitor: SyntaxVisitor {
    private let filePath: String
    private let moduleName: String
    private let builder: ArchitectureModelBuilder

    init(filePath: String, moduleName: String, builder: ArchitectureModelBuilder) {
        self.filePath = filePath
        self.moduleName = moduleName
        self.builder = builder
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Visit methods for different syntax nodes

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract module name from import declaration
        if let moduleNameToken = node.path.first?.name {
            let moduleName = moduleNameToken.text

            // Create a source location
            let location = SourceLocation(
                file: filePath,
                line: getLineNumber(for: node),
                column: getColumnNumber(for: node)
            )

            let importStatement = ImportStatement(
                moduleName: moduleName,
                location: location
            )

            builder.addImport(importStatement, toModule: self.moduleName)
        }

        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let className = node.name.text

        // Source location
        let location = SourceLocation(
            file: filePath,
            line: getLineNumber(for: node),
            column: getColumnNumber(for: node)
        )

        // Parse access level
        let accessLevel = parseAccessLevel(from: node.modifiers)

        // Parse attributes
        let attributes = parseAttributes(from: node.attributes)

        // Parse inheritance and conformances
        let (inheritedTypes, conformances) = parseInheritance(from: node.inheritanceClause)

        // Create a placeholder for the class - methods and properties will be added during full traversal
        let swiftClass = SwiftClass(
            name: className,
            fullyQualifiedName: "\(moduleName).\(className)",
            location: location,
            attributes: attributes,
            accessLevel: accessLevel,
            inheritedTypes: inheritedTypes,
            conformances: conformances,
            containingModule: SwiftModule(name: moduleName, location: "")
        )

        builder.addType(swiftClass, toModule: moduleName)

        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let structName = node.name.text

        // Source location
        let location = SourceLocation(
            file: filePath,
            line: getLineNumber(for: node),
            column: getColumnNumber(for: node)
        )

        // Parse access level
        let accessLevel = parseAccessLevel(from: node.modifiers)

        // Parse attributes
        let attributes = parseAttributes(from: node.attributes)

        // Parse inheritance and conformances
        let (_, conformances) = parseInheritance(from: node.inheritanceClause)

        // Create a placeholder for the struct
        let swiftStruct = SwiftStruct(
            name: structName,
            fullyQualifiedName: "\(moduleName).\(structName)",
            location: location,
            attributes: attributes,
            accessLevel: accessLevel,
            conformances: conformances,
            containingModule: SwiftModule(name: moduleName, location: "")
        )

        builder.addType(swiftStruct, toModule: moduleName)

        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let enumName = node.name.text

        // Source location
        let location = SourceLocation(
            file: filePath,
            line: getLineNumber(for: node),
            column: getColumnNumber(for: node)
        )

        // Parse access level
        let accessLevel = parseAccessLevel(from: node.modifiers)

        // Parse attributes
        let attributes = parseAttributes(from: node.attributes)

        // Parse inheritance and conformances
        let (inheritedTypes, conformances) = parseInheritance(from: node.inheritanceClause)

        // Create a placeholder for the enum
        let swiftEnum = SwiftEnum(
            name: enumName,
            fullyQualifiedName: "\(moduleName).\(enumName)",
            location: location,
            attributes: attributes,
            accessLevel: accessLevel,
            inheritedTypes: inheritedTypes,
            conformances: conformances,
            containingModule: SwiftModule(name: moduleName, location: "")
        )

        builder.addType(swiftEnum, toModule: moduleName)

        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let protocolName = node.name.text

        // Source location
        let location = SourceLocation(
            file: filePath,
            line: getLineNumber(for: node),
            column: getColumnNumber(for: node)
        )

        // Parse access level
        let accessLevel = parseAccessLevel(from: node.modifiers)

        // Parse attributes
        let attributes = parseAttributes(from: node.attributes)

        // Parse inheritance
        let (inheritedTypes, _) = parseInheritance(from: node.inheritanceClause)

        // Create a placeholder for the protocol
        let swiftProtocol = SwiftProtocol(
            name: protocolName,
            fullyQualifiedName: "\(moduleName).\(protocolName)",
            location: location,
            attributes: attributes,
            accessLevel: accessLevel,
            inheritedTypes: inheritedTypes,
            conformances: [],
            containingModule: SwiftModule(name: moduleName, location: "")
        )

        builder.addType(swiftProtocol, toModule: moduleName)

        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let functionName = node.name.text

        // Source location
        let location = SourceLocation(
            file: filePath,
            line: getLineNumber(for: node),
            column: getColumnNumber(for: node)
        )

        // Parse access level and other modifiers
        let accessLevel = parseAccessLevel(from: node.modifiers)
        let isStatic = node.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }

        // Parse attributes
        let attributes = parseAttributes(from: node.attributes)

        // Parse parameters
        let parameters = parseParameters(from: node.signature.parameterClause)

        // Parse return type
        let returnType = parseReturnType(from: node.signature.returnClause)

        // Determine if this is an override
        let isOverride = node.modifiers.contains { $0.name.text == "override" }

        // Create method (standalone function for now, will be linked to containing type later)
        let method = SwiftMethod(
            name: functionName,
            fullyQualifiedName: "\(moduleName).\(functionName)",
            location: location,
            attributes: attributes,
            accessLevel: accessLevel,
            isStatic: isStatic,
            parameters: parameters,
            returnType: returnType,
            isOverride: isOverride
        )

        // Note: In a complete implementation, we would:
        // 1. Find containing type (if any) and add this method to it
        // 2. Extract dependencies from parameter types and return type

        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Parse access level and other modifiers
        let accessLevel = parseAccessLevel(from: node.modifiers)
        let isStatic = node.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }

        // Parse attributes
        let attributes = parseAttributes(from: node.attributes)

        // Process each binding (there might be multiple properties in one declaration)
        for binding in node.bindings {
            if let patternBinding = binding.pattern.as(IdentifierPatternSyntax.self) {
                let propertyName = patternBinding.identifier.text

                // Source location
                let location = SourceLocation(
                    file: filePath,
                    line: getLineNumber(for: binding),
                    column: getColumnNumber(for: binding)
                )

                // Parse type annotation
                var typeReference: TypeReference?

                if let typeAnnotation = binding.typeAnnotation {
                    typeReference = parseTypeReference(from: typeAnnotation.type)
                }

                // Determine if computed property
                let isComputed = binding.accessorBlock?.is(AccessorBlockSyntax.self) ?? false

                // Create property if type is known
                if let typeRef = typeReference {
                    let property = SwiftProperty(
                        name: propertyName,
                        fullyQualifiedName: "\(moduleName).\(propertyName)",
                        location: location,
                        attributes: attributes,
                        accessLevel: accessLevel,
                        isStatic: isStatic,
                        type: typeRef,
                        isComputed: isComputed
                    )

                    // Note: In a complete implementation, we would:
                    // 1. Find containing type (if any) and add this property to it
                    // 2. Extract dependencies from the property type
                }
            }
        }

        return .visitChildren
    }

    // MARK: - Helper methods for parsing syntax elements

    /// Extract access level from modifiers
    private func parseAccessLevel(from modifiers: DeclModifierListSyntax?) -> AccessLevel {
        guard let modifiers = modifiers else {
            return .default
        }

        for modifier in modifiers {
            switch modifier.name.text {
            case "private":
                return .private
            case "fileprivate":
                return .fileprivate
            case "internal":
                return .internal
            case "public":
                return .public
            case "open":
                return .open
            default:
                continue
            }
        }

        return .default
    }

    /// Extract attributes from syntax
    private func parseAttributes(from attributes: AttributeListSyntax?) -> [SwiftAttribute] {
        guard let attributes = attributes else {
            return []
        }

        var result: [SwiftAttribute] = []

        for attribute in attributes {
            if let attributeSyntax = attribute.as(AttributeSyntax.self) {
                let attributeName = attributeSyntax.attributeName.description.trimmingCharacters(in: .whitespacesAndNewlines)

                // Extract arguments (simplified implementation)
                var arguments: [String: String] = [:]

                if let argumentList = attributeSyntax.arguments?.as(LabeledExprListSyntax.self) {
                    for argumentItem in argumentList {
                        if let label = argumentItem.label?.text,
                           let expression = argumentItem.expression.as(StringLiteralExprSyntax.self) {
                            arguments[label] = expression.segments.description
                        }
                    }
                }

                // Create the attribute
                let location = SourceLocation(
                    file: filePath,
                    line: getLineNumber(for: attributeSyntax),
                    column: getColumnNumber(for: attributeSyntax)
                )

                let attribute = SwiftAttribute(
                    name: attributeName,
                    arguments: arguments,
                    location: location
                )

                result.append(attribute)
            }
        }

        return result
    }

    /// Extract inheritance and conformance information
    private func parseInheritance(from inheritanceClause: InheritanceClauseSyntax?) -> (inheritedTypes: [TypeReference], conformances: [TypeReference]) {
        var inheritedTypes: [TypeReference] = []
        let conformances: [TypeReference] = []

        guard let inheritanceClause = inheritanceClause else {
            return (inheritedTypes, conformances)
        }

        for inheritedType in inheritanceClause.inheritedTypes {
            if let simpleType = inheritedType.type.as(IdentifierTypeSyntax.self) {
                let typeName = simpleType.name.text
                let typeReference = TypeReference(name: typeName)

                // Note: In a complete implementation, we would use more sophisticated
                // logic to determine if this is a class inheritance or protocol conformance
                // For simplicity, we're just assuming class inheritance for now
                inheritedTypes.append(typeReference)
            }
        }

        return (inheritedTypes, conformances)
    }

    /// Extract parameters from a function declaration
    private func parseParameters(from parameterClause: FunctionParameterClauseSyntax) -> [MethodParameter] {
        var parameters: [MethodParameter] = []

        for parameter in parameterClause.parameters {
            let paramName = parameter.firstName.text
            let paramLabel = parameter.secondName?.text

            // Determine parameter type
            let typeAnnotation = parameter.type
            let typeRef = parseTypeReference(from: typeAnnotation)

            // Check if there's a default value
            let hasDefaultValue = parameter.defaultValue != nil

            let methodParameter = MethodParameter(
                label: paramLabel,
                name: paramName,
                type: typeRef,
                hasDefaultValue: hasDefaultValue
            )

            parameters.append(methodParameter)
        }

        return parameters
    }

    /// Extract return type from a function declaration
    private func parseReturnType(from returnClause: ReturnClauseSyntax?) -> TypeReference? {
        guard let returnClause = returnClause else {
            return nil
        }

        return parseTypeReference(from: returnClause.type)
    }

    /// Parse a type reference from a TypeSyntax
    private func parseTypeReference(from typeSyntax: TypeSyntax) -> TypeReference {
        // Handle simple types
        if let simpleType = typeSyntax.as(IdentifierTypeSyntax.self) {
            // This is a simplification - in a real implementation, we would:
            // 1. Resolve the module name if available
            // 2. Handle generic types
            // 3. Handle composed types (A & B)
            return TypeReference(name: simpleType.name.text)
        }

        // Handle other type kinds (optional, array, dictionary, etc.)
        // This is a simplified implementation
        return TypeReference(name: typeSyntax.description.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Source Location Helpers

    /// Get the line number for a syntax node
    /// - Parameter node: The syntax node
    /// - Returns: The line number
    private func getLineNumber(for node: SyntaxProtocol) -> Int {
        // In a real implementation, you would use a SourceLocationConverter
        // to get the real line number from the node's position in the source file
        // This is a simplified implementation
        return 0
    }

    /// Get the column number for a syntax node
    /// - Parameter node: The syntax node
    /// - Returns: The column number
    private func getColumnNumber(for node: SyntaxProtocol) -> Int {
        // In a real implementation, you would use a SourceLocationConverter
        // to get the real column number from the node's position in the source file
        // This is a simplified implementation
        return 0
    }
}

// MARK: - Error Handling

/// Errors that can occur during the architecture analysis
public enum SwiftArchError: Error {
    case directoryNotFound(path: String)
    case fileParsingFailed(path: String, reason: String)
    case unableToResolveReference(name: String)
}
