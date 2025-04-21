import Foundation
import SwiftSyntax
import SwiftParser

/// Visitor that walks the SwiftSyntax AST and collects declarations
class SwiftSyntaxVisitor: SyntaxVisitor {
    private let filePath: String
    private let converter: SourceLocationConverter

    private var imports: [SwiftImportDeclaration] = []
    private var classes: [SwiftClassDeclaration] = []
    private var structs: [SwiftStructDeclaration] = []
    private var protocols: [SwiftProtocolDeclaration] = []
    private var extensions: [SwiftExtensionDeclaration] = []
    private var topLevelFunctions: [SwiftFunctionDeclaration] = []
    private var topLevelProperties: [SwiftPropertyDeclaration] = []
    private var enums: [SwiftEnumDeclaration] = []

    // Updated initializer
    init(filePath: String, converter: SourceLocationConverter) {
        self.filePath = filePath
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    // Helper to check if a node is a member of a type/extension
    private func isMember(_ node: Syntax) -> Bool {
        var current: Syntax? = node.parent // Start with the immediate parent

        while let parent = current {
            // Check if the parent is one of the container types where members reside
            // Note: Members inside protocols define requirements.
            if parent.is(MemberBlockSyntax.self) {
                // If the parent is specifically a MemberBlockSyntax, it's definitely a member
                // Check the MemberBlockSyntax's parent to see what kind of declaration it belongs to
                if let grandparent = parent.parent {
                    if grandparent.is(ClassDeclSyntax.self) ||
                        grandparent.is(StructDeclSyntax.self) ||
                        grandparent.is(EnumDeclSyntax.self) ||
                        grandparent.is(ProtocolDeclSyntax.self) ||
                        grandparent.is(ExtensionDeclSyntax.self) {
                        return true // It's a member block of a supported type/extension
                    }
                }
                // If it's a MemberBlockSyntax but not directly in one of the above,
                // treat it as not a top-level member for our purposes (e.g., nested types)
                // Or potentially continue searching upwards? For simplicity, let's count it as a member context.
                return true
            }

            // Added check: If inside a function body, it's not a top-level property/function either
            if parent.is(CodeBlockSyntax.self) && parent.parent?.is(FunctionDeclSyntax.self) == true {
                return true // It's inside a function body
            }

            // Stop if we reach the top-level source file node
            if parent.is(SourceFileSyntax.self) {
                return false // Reached the top without finding a container type
            }

            // Move up to the next parent
            current = parent.parent
        }

        // If the loop finishes without finding a relevant container or SourceFile,
        // it means it's likely top-level or in an unsupported context.
        return false
    }

    // Updated getLocation to use converter and accept Syntax node
    private func getLocation(for node: Syntax) -> SourceLocation {
        let location = node.startLocation(converter: converter)
        return SourceLocation(
            file: filePath,
            line: location.line,
            column: location.column
        )
    }

    // --- Visit Methods for Container Types (Import, Class, Struct, Enum, Protocol, Extension) ---
    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = getLocation(for: Syntax(node))
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var moduleName = ""
        var submodules: [String] = []
        var determinedKind: SwiftImportDeclaration.ImportKind

        let pathComponents = node.path
        if let firstComponent = pathComponents.first {
            moduleName = firstComponent.name.text

            if pathComponents.count > 1 {
                submodules = pathComponents.dropFirst().map { $0.name.text }
            }
        }

        if node.importKindSpecifier != nil {
            determinedKind = .typeOnly
        } else if !submodules.isEmpty {
            determinedKind = .component
        } else {
            determinedKind = .regular
        }

        let importDecl = SwiftImportDeclaration(
            name: moduleName,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: [],
            filePath: filePath,
            location: location,
            kind: determinedKind,
            submodules: submodules
        )

        imports.append(importDecl)

        return .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = getLocation(for: Syntax(node))
        let name = node.name.text
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var currentDependencies: [SwiftDependency] = []
        var protocols: [String] = []
        var rawType: String? = nil

        var genericParameterNames = Set<String>()
        if let genericClause = node.genericParameterClause {
            for genericParam in genericClause.parameters {
                genericParameterNames.insert(genericParam.name.text)
            }
        }

        if let inheritanceClause = node.inheritanceClause {
            for inheritance in inheritanceClause.inheritedTypes {
                let typeSyntax = Syntax(inheritance.type)
                let typeName = typeSyntax.trimmedDescription
                let depLocation = getLocation(for: typeSyntax)


                // Check common raw types (adjust list as needed) TODO:
                let commonRawTypes = ["String", "Int", "UInt", "Float", "Double", "Character", "RawRepresentable"]
                if rawType == nil, commonRawTypes.contains(where: { typeName.hasPrefix($0) }) {
                    // Crude check for raw type - might need refinement for complex cases
                    // Check if it's actually *just* the type name or conforms to RawRepresentable
                    // For simplicity, we assume the first potential raw type is the one.
                    rawType = typeName

                    for extractedName in extractTypeNames(from: typeName) {
                        currentDependencies.append(
                            SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
                        )
                    }
                } else {
                    protocols.append(typeName)

                    for extractedName in extractTypeNames(from: typeName) {
                        currentDependencies.append(
                            SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
                        )
                    }
                }
            }
        }

        if let genericClause = node.genericParameterClause {
            for genericParam in genericClause.parameters {
                if let constraintType = genericParam.inheritedType {
                    let typeSyntax = Syntax(constraintType)
                    let typeName = typeSyntax.trimmedDescription
                    let depLocation = getLocation(for: typeSyntax)
                    for extractedName in extractTypeNames(from: typeName) {
                        currentDependencies.append(SwiftDependency(name: extractedName, kind: .conformance, location: depLocation))
                    }
                }
            }
        }

        var cases: [SwiftEnumDeclaration.EnumCase] = []

        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
        memberVisitor.walk(node.memberBlock)
        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }

        for member in node.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for caseElement in caseDecl.elements {
                    let caseName = caseElement.name.text
                    var associatedValueStrings: [String]? = nil

                    if let parameterClause = caseElement.parameterClause {
                        associatedValueStrings = [] // Initialize only if clause exists
                        for param in parameterClause.parameters {
                            let typeSyntax = param.type
                            let typeName = typeSyntax.trimmedDescription
                            associatedValueStrings?.append(typeName) // Store raw string

                            let depLocation = getLocation(for: Syntax(typeSyntax))
                            for extractedName in extractTypeNames(from: typeName) {
                                if !genericParameterNames.contains(extractedName) {
                                    currentDependencies.append(
                                        SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
                                    )
                                }
                            }
                        }
                    }
                    let rawValue = caseElement.rawValue?.value.trimmedDescription

                    cases.append(SwiftEnumDeclaration.EnumCase(
                        name: caseName,
                        associatedValues: associatedValueStrings,
                        rawValue: rawValue
                    ))
                }
            }
        }

        let enumDecl = SwiftEnumDeclaration(
            name: name,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: currentDependencies,
            filePath: filePath,
            location: location,
            cases: cases,
            properties: memberVisitor.properties,
            methods: memberVisitor.methods,
            rawType: rawType,
            protocols: protocols
        )

        enums.append(enumDecl)

        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = getLocation(for: Syntax(node))
        let name = node.name.text
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var currentDependencies: [SwiftDependency] = []
        var superClass: String? = nil
        var protocols: [String] = []

        if let inheritanceClause = node.inheritanceClause {
            for (index, inheritance) in inheritanceClause.inheritedTypes.enumerated() {
                let typeSyntax = Syntax(inheritance.type)
                let typeName = typeSyntax.trimmedDescription // Raw type string
                let depLocation = getLocation(for: typeSyntax) // Location of the type name

                // First type for a class *might* be the superclass. Heuristic: doesn't look like a common protocol name.
                // This is imperfect. Proper semantic analysis is needed for 100% accuracy.
                if index == 0 /* && !isLikelyProtocol(typeName) */ {
                    superClass = typeName
                    for extractedName in extractTypeNames(from: typeName) {
                        currentDependencies.append(
                            SwiftDependency(name: extractedName, kind: .inheritance, location: depLocation)
                        )
                    }
                } else {
                    protocols.append(typeName)

                    for extractedName in extractTypeNames(from: typeName) {
                        currentDependencies.append(
                            SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
                        )
                    }
                }
            }
        }

        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
        memberVisitor.walk(node.memberBlock)
        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }

        let classDecl = SwiftClassDeclaration(
            name: name,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: currentDependencies,
            filePath: filePath,
            location: location,
            superClass: superClass,
            protocols: protocols,
            properties: memberVisitor.properties,
            methods: memberVisitor.methods
        )
        classes.append(classDecl)
        return .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = getLocation(for: Syntax(node))
        let name = node.name.text
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var currentDependencies: [SwiftDependency] = []
        var protocols: [String] = []

        if let inheritanceClause = node.inheritanceClause {
            protocols = inheritanceClause.inheritedTypes.map {
                let typeSyntax = Syntax($0.type)
                let typeName = typeSyntax.trimmedDescription
                let depLocation = getLocation(for: typeSyntax)

                for extractedName in extractTypeNames(from: typeName) {
                    currentDependencies.append(
                        SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
                    )
                }
                return typeName
            }
        }

        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
        memberVisitor.walk(node.memberBlock)
        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }

        let structDecl = SwiftStructDeclaration(
            name: name,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: currentDependencies,
            filePath: filePath,
            location: location,
            protocols: protocols,
            properties: memberVisitor.properties,
            methods: memberVisitor.methods
        )
        structs.append(structDecl)
        return .skipChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = getLocation(for: Syntax(node))
        let name = node.name.text
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var currentDependencies: [SwiftDependency] = []
        var inheritedProtocols: [String] = []

        if let inheritanceClause = node.inheritanceClause {
            inheritedProtocols = inheritanceClause.inheritedTypes.map {
                let typeSyntax = Syntax($0.type)
                let typeName = typeSyntax.trimmedDescription
                let depLocation = getLocation(for: typeSyntax)

                for extractedName in extractTypeNames(from: typeName) {
                    currentDependencies.append(
                        SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
                    )
                }

                return typeName
            }
        }

        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
        memberVisitor.walk(node.memberBlock)
        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }

        let protocolDecl = SwiftProtocolDeclaration(
            name: name,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: currentDependencies,
            filePath: filePath,
            location: location,
            inheritedProtocols: inheritedProtocols,
            propertyRequirements: memberVisitor.properties,
            methodRequirements: memberVisitor.methods
        )
        protocols.append(protocolDecl)
        return .skipChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let location = getLocation(for: Syntax(node))
        let name = node.extendedType.trimmedDescription
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var currentDependencies: [SwiftDependency] = []
        var protocols: [String] = []

        if let inheritanceClause = node.inheritanceClause {
            protocols = inheritanceClause.inheritedTypes.map {
                let typeSyntax = Syntax($0.type)
                let typeName = typeSyntax.trimmedDescription
                let depLocation = getLocation(for: typeSyntax)

                for extractedName in extractTypeNames(from: typeName) {
                    currentDependencies.append(
                        SwiftDependency(name: extractedName, kind: .conformance, location: depLocation)
                    )
                }

                return typeName
            }
        }

        let typeSyntax = Syntax(node.extendedType)
        let typeName = typeSyntax.trimmedDescription
        let depLocation = getLocation(for: typeSyntax)

        for extractedName in extractTypeNames(from: typeName) {
            currentDependencies.append(
                SwiftDependency(name: extractedName, kind: .extension, location: depLocation)
            )
        }

        let memberVisitor = MemberCollector(filePath: filePath, converter: converter)
        memberVisitor.walk(node.memberBlock)
        memberVisitor.properties.forEach { currentDependencies.append(contentsOf: $0.dependencies) }
        memberVisitor.methods.forEach { currentDependencies.append(contentsOf: $0.dependencies) }

        let extensionDecl = SwiftExtensionDeclaration(
            name: name,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: currentDependencies,
            filePath: filePath,
            location: location,
            properties: memberVisitor.properties,
            methods: memberVisitor.methods,
            protocols: protocols
        )

        extensions.append(extensionDecl)

        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        var currentDependencies: [SwiftDependency] = []

            if !isMember(Syntax(node)) {
                let location = getLocation(for: Syntax(node))
                let name = node.name.text
                let modifiers = extractModifiers(from: node.modifiers)
                let annotations = extractAnnotations(from: node.attributes)
                let parameterList = node.signature.parameterClause.parameters
                let parameters = extractParameters(from: parameterList)
                let returnType = node.signature.returnClause?.type.trimmedDescription
                let body = node.body?.trimmedDescription
                let effectSpecifiers = extractEffectSpecifiers(from: node.signature)

                parameterList.forEach { param in
                    let typeSyntax = Syntax(param.type)
                    let typeName = typeSyntax.trimmedDescription
                    let depLocation = getLocation(for: typeSyntax)

                    for extractedName in extractTypeNames(from: typeName) {
                        currentDependencies.append(
                            SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
                        )
                    }
                }

                if let returnType = node.signature.returnClause {
                    let depLocation = getLocation(for: Syntax(returnType))
                    for extractedName in extractTypeNames(from: returnType.type.trimmedDescription) {
                        currentDependencies.append(
                            SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
                        )
                    }
                }

                let functionDecl = SwiftFunctionDeclaration(
                    name: name,
                    modifiers: modifiers,
                    annotations: annotations,
                    dependencies: currentDependencies,
                    filePath: filePath,
                    location: location,
                    parameters: parameters,
                    returnType: returnType,
                    body: body,
                    effectSpecifiers: effectSpecifiers
                )
                topLevelFunctions.append(functionDecl)
            }

            return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        var currentDependencies: [SwiftDependency] = []

        if !isMember(Syntax(node)) {
            let modifiers = extractModifiers(from: node.modifiers)
            let annotations = extractAnnotations(from: node.attributes)

            for binding in node.bindings {
                // Ensure it's a simple identifier pattern (e.g., `let x = 1`, not `let (a, b) = (1, 2)`)
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                    let location = getLocation(for: Syntax(pattern))
                    let name = pattern.identifier.text

                    var type: String = "Any"
                    // Flag to avoid duplicate dependency if type inferred
                    var dependencyCreated = false

                    if let typeAnnotation = binding.typeAnnotation {
                        let typeSyntax = Syntax(typeAnnotation.type)
                        type = typeSyntax.trimmedDescription
                        let depLocation = getLocation(for: typeSyntax)
                        for extractedName in extractTypeNames(from: type) {
                            currentDependencies.append(
                                SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
                            )
                            dependencyCreated = true
                        }
                    }

                    let initialValue = binding.initializer?.value

                    if !dependencyCreated, let initializerExpr = initialValue {
                        let inferredTypeName = inferTypeName(from: initializerExpr)
                        if let inferredTypeName = inferredTypeName {
                            type = inferredTypeName
                            let depLocation = getLocation(for: Syntax(initializerExpr))

                            for extractedName in extractTypeNames(from: inferredTypeName) {
                                currentDependencies.append(
                                    SwiftDependency(name: extractedName, kind: .typeUsage, location: depLocation)
                                )
                            }
                        }
                    }

                    // Check if computed based on accessor block presence
                    let isComputed = binding.accessorBlock != nil
                    let propertyDecl = SwiftPropertyDeclaration(
                        name: name,
                        modifiers: modifiers,
                        annotations: annotations,
                        dependencies: currentDependencies,
                        filePath: filePath,
                        location: location,
                        type: type,
                        isComputed: isComputed,
                        initialValue: initialValue?.trimmedDescription
                    )
                    topLevelProperties.append(propertyDecl)
                }
            }
        }

        return .skipChildren
    }

    /// Attempts to infer a base type name from a common initializer expression syntax.
    /// Returns a simplified type name string or nil if inference fails.
    private func inferTypeName(from expression: ExprSyntax) -> String? {
        if let funcCall = expression.as(FunctionCallExprSyntax.self) {
            // Handles SomeType(...) or SomeModule.SomeType(...)
            return inferTypeName(from: funcCall.calledExpression) // Recurse on the expression being called
        } else if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            // Handles variable.method(...) or variable.property or EnumType.case
            // We are interested in the type of the base, e.g. "EnumType" from EnumType.case
            // If base is nil, it's implicit self or static member access like ".zero" - hard to infer type here.
            if let base = memberAccess.base {
                return inferTypeName(from: base) // Recurse on the base
            } else {
                // Attempt to get type from the member name if it's a static member/enum case? Heuristic.
                // e.g., ".shared" -> could be anything. Need context.
                // Let's return nil for implicit base for now.
                return nil
            }
        } else if let identifier = expression.as(DeclReferenceExprSyntax.self) {
            // Handles SomeType (e.g., in SomeType.init(...)) or variable names
            let name = identifier.baseName.text
            // Simple heuristic: If it starts with uppercase, assume it's a type name.
            if name.first?.isUppercase == true {
                return name
            }
        }
        //        else if let explicitMember = expression.as(ExplicitMemberExprSyntax.self) {
        //            // Handles .case(...) or .staticMember(...)
        //            // Try to infer from base type if possible
        //            if let base = explicitMember.base {
        //                return inferTypeName(from: base)
        //            } else {
        //                // e.g. ".shared" called directly, cannot infer base type easily
        //                return nil
        //            }
        //        }

        // Fallback
        return nil
    }

    func extractTypeNames(from typeString: String?) -> Set<String> {
        guard let cleaned = typeString?.trimmingCharacters(in: .whitespacesAndNewlines) else { return [] }
        // Very basic: remove common wrappers and split by non-alphanumeric
        let baseTypes = cleaned
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.first?.isUppercase == true } // Keep only potential type names

        // TODO: Add common lowercase types like 'any', 'some' if needed

        return Set(baseTypes)
    }

    func extractModifiers(from modifierList: DeclModifierListSyntax?) -> [SwiftModifier] {
        var modifiers: [SwiftModifier] = []
        guard let modifierList = modifierList else {
            return modifiers
        }

        for modifier in modifierList {
            let name = modifier.name.text

            if let swiftModifier = SwiftModifier(rawValue: name) {
                modifiers.append(swiftModifier)
            }
        }

        return modifiers
    }

    func extractAnnotations(from attributeList: AttributeListSyntax?) -> [SwiftAnnotation] {
        var annotations: [SwiftAnnotation] = []
        guard let attributeList = attributeList else { return annotations }

        for attributeElement in attributeList {
            // Attributes can be wrapped in #if blocks, handle AttributeSyntax directly
            guard let attribute = attributeElement.as(AttributeSyntax.self) else {
                // Skip if it's not a simple attribute (e.g., inside #if)
                continue
            }

            let name = attribute.attributeName.trimmedDescription
            var arguments: [String: String] = [:]

            // Handle different argument syntaxes using the enum cases of AttributeSyntax.Arguments
            if let args = attribute.arguments {
                switch args {
                case .argumentList(let tupleExprElements):
                    for element in tupleExprElements {
                        let label = element.label?.text
                        let value = element.expression.trimmedDescription

                        // Determine the key for the arguments dictionary
                        // Use label if it exists, otherwise use "_" for unnamed/positional args
                        // Note: Multiple unnamed args will overwrite the "_" key here.
                        // A list might be better for unnamed args if order/multiplicity matters.
                        let key = label ?? "_"

                        arguments[key] = value
                    }
                case .string(let stringLiteralExprSyntax):
                    // Handles hypothetical @Attribute("someString") syntax if ever used
                    // This case seems less common for typical attributes.
                    arguments["_"] = stringLiteralExprSyntax.segments.trimmedDescription
                case .availability(let availabilityArgumentListSyntax):
                    for syntax in availabilityArgumentListSyntax {
                        let argument = Syntax(syntax.argument)
                        if argument.is(PlatformVersionSyntax.self) {
                            let version = argument.cast(PlatformVersionSyntax.self)
                            arguments[version.platform.text] = version.version?.trimmedDescription
                        }
                    }
                default:
                    print("Unhandled attribute argument type: \(args.syntaxNodeType) for attribute \(name)")
                }
            }
            annotations.append(SwiftAnnotation(name: name, arguments: arguments))
        }
        return annotations
    }

    func extractParameters(from parameterList: FunctionParameterListSyntax) -> [SwiftParameterDeclaration] {
        return parameterList.map { parameter in
            // Handle cases like `_ name: Type` or `name: Type`
            let name = parameter.secondName?.text ?? parameter.firstName.text
            // Handle type variations (simple, optional, closure, etc.)
            let type = parameter.type.trimmedDescription
            let defaultValue = parameter.defaultValue?.value.trimmedDescription
            return SwiftParameterDeclaration(name: name, type: type, defaultValue: defaultValue)
        }
    }

    func makeSwiftFile() -> SwiftFile {
        SwiftFile(
            path: filePath,
            imports: imports,
            classes: classes,
            structs: structs,
            protocols: protocols,
            extensions: extensions,
            functions: topLevelFunctions,
            properties: topLevelProperties,
            enums: enums
        )
    }
}

extension SyntaxVisitor {
    func extractEffectSpecifiers(from signature: FunctionSignatureSyntax) -> SwiftFunctionDeclaration.FunctionEffectSpecifiers {
        let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let isRethrows = signature.effectSpecifiers?.throwsClause?.throwsSpecifier.text == "rethrows"

        return SwiftFunctionDeclaration.FunctionEffectSpecifiers(
            isAsync: isAsync,
            isThrowing: isThrows && !isRethrows,
            isRethrows: isRethrows
        )
    }
}
