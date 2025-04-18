import Foundation
import SwiftSyntax
import SwiftParser

/// Helper class to collect members from declarations
class MemberCollector: SyntaxVisitor {
    var properties: [SwiftPropertyDeclaration] = []
    var methods: [SwiftFunctionDeclaration] = []
    private let filePath: String
    private let converter: SourceLocationConverter

    init(filePath: String, converter: SourceLocationConverter, viewMode: SyntaxTreeViewMode = .sourceAccurate) {
        self.filePath = filePath
        self.converter = converter
        super.init(viewMode: viewMode)
    }

    private func getLocation(for node: Syntax) -> SourceLocation {
        let location = node.startLocation(converter: converter)
        return SourceLocation(
            file: filePath,
            line: location.line,
            column: location.column
        )
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        var currentDependencies: [SwiftDependency] = []

        let location = getLocation(for: Syntax(node))
        let name = "init"
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)
        let parameterList = node.signature.parameterClause.parameters
        let parameters = extractParameters(from: parameterList)
        let returnType: String? = nil
        let body = node.body?.trimmedDescription

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

        let initDecl = SwiftFunctionDeclaration(
            name: name,
            modifiers: modifiers,
            annotations: annotations,
            dependencies: currentDependencies,
            filePath: filePath,
            location: location,
            parameters: parameters,
            returnType: returnType,
            body: body
        )

        methods.append(initDecl)

        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        var currentDependencies: [SwiftDependency] = []

        let location = getLocation(for: Syntax(node))
        let name = node.name.text
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)
        let parameterList = node.signature.parameterClause.parameters
        let parameters = extractParameters(from: parameterList)
        let returnType = node.signature.returnClause?.type.trimmedDescription
        let body = node.body?.trimmedDescription

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
            body: body
        )
        methods.append(functionDecl)
        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let modifiers = extractModifiers(from: node.modifiers)
        let annotations = extractAnnotations(from: node.attributes)

        var currentDependencies: [SwiftDependency] = []

        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let location = getLocation(for: Syntax(pattern))
                let name = pattern.identifier.text
                let isComputed = binding.accessorBlock != nil

                var type: String = "Any"
                // Flag to avoid duplicate dependency if type inferred
                var dependencyCreated = false

                if let typeAnnotation = binding.typeAnnotation {
                    let typeSyntax = Syntax(typeAnnotation.type)
                    type = typeSyntax.trimmedDescription
                    let extractedNames = extractTypeNames(from: type)
                    let depLocation = getLocation(for: typeSyntax)
                    for extractedName in extractedNames {
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
                properties.append(propertyDecl)
            }
        }

        return .skipChildren
    }

    // --- Helper Methods ---

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

    // TODO: These should be identical to the ones in SwiftSyntaxVisitor or refactored into a common utility. For now, duplicate them.
    private func extractTypeNames(from typeString: String?) -> Set<String> {
        guard let cleaned = typeString?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return []
        }

        let baseTypes = cleaned
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.first?.isUppercase == true }

        // TODO: Add common lowercase types like 'any', 'some' if needed

        return Set(baseTypes)
    }

    private func extractModifiers(from modifierList: DeclModifierListSyntax?) -> [SwiftModifier] {
        var modifiers: [SwiftModifier] = []
        guard let modifierList = modifierList else { return modifiers }
        for modifier in modifierList {
            if let swiftModifier = SwiftModifier(rawValue: modifier.name.text) {
                modifiers.append(swiftModifier)
            }
        }
        return modifiers
    }

    private func extractAnnotations(from attributeList: AttributeListSyntax?) -> [SwiftAnnotation] {
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
                    // This handles cases like @MyAttribute(label: value, value2, label3: value3)
                    for element in tupleExprElements {
                        let label = element.label?.text // Label if present (e.g., "deprecated:")
                        let value = element.expression.trimmedDescription // The argument value description

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
                    // Handles @available(*, deprecated: "message", ...) where the elements
                    // contain AvailabilityArgumentSyntax nodes.
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

    private func extractParameters(from parameterList: FunctionParameterListSyntax) -> [SwiftParameterDeclaration] {
        return parameterList.map { parameter in
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let type = parameter.type.trimmedDescription
            let defaultValue = parameter.defaultValue?.value.trimmedDescription
            return SwiftParameterDeclaration(name: name, type: type, defaultValue: defaultValue)
        }
    }

    private func extractReturnType(from output: ReturnClauseSyntax?) -> String? {
        return output?.type.trimmedDescription
    }
}

extension SyntaxProtocol {
    var trimmedDescription: String {
        return description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
