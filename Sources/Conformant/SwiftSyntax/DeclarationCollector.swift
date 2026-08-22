//
//  DeclarationCollector.swift
//  Conformant
//
//  Copyright © 2025 Prince Ugwuh. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Foundation
import SwiftSyntax
import SwiftParser

/// Walks a parsed source file and collects every declaration form it contains.
///
/// This replaces the earlier `SwiftSyntaxVisitor` / `MemberCollector` pair. That design
/// had two problems the split itself caused:
///
/// * The two visitors duplicated their extraction helpers, so a fix to one silently left
///   the other behind.
/// * Container visits returned `.skipChildren` and then ran a *member* visitor over the
///   member block. Because the member visitor did not stop at a nested type, the members
///   of `Outer.Inner` were reported as members of `Outer`, and `Inner` itself was never
///   collected at all.
///
/// The collector is an explicit recursive descent over declarations instead. A nested
/// type is collected in its own right, under a qualified name and with a reference to its
/// parent, and its dependencies stay attached to it rather than leaking outward.
///
/// Traversal deliberately stops at function and accessor bodies: a type declared inside a
/// function body is local to that call and is not part of the file's architecture.
/// Conditional-compilation blocks are *not* filtered — every `#if` branch is collected,
/// because the parser has no build configuration to evaluate them against.
final class DeclarationCollector {
    private let filePath: String
    private let converter: SourceLocationConverter
    let diagnostics: DiagnosticSink

    private(set) var imports: [SwiftImportDeclaration] = []
    private(set) var classes: [SwiftClassDeclaration] = []
    private(set) var structs: [SwiftStructDeclaration] = []
    private(set) var actors: [SwiftActorDeclaration] = []
    private(set) var enums: [SwiftEnumDeclaration] = []
    private(set) var protocols: [SwiftProtocolDeclaration] = []
    private(set) var extensions: [SwiftExtensionDeclaration] = []
    private(set) var typealiases: [SwiftTypealiasDeclaration] = []
    private(set) var macros: [SwiftMacroDeclaration] = []
    private(set) var operators: [SwiftOperatorDeclaration] = []
    private(set) var precedenceGroups: [SwiftPrecedenceGroupDeclaration] = []
    private(set) var topLevelFunctions: [SwiftFunctionDeclaration] = []
    private(set) var topLevelProperties: [SwiftPropertyDeclaration] = []

    init(filePath: String, converter: SourceLocationConverter, diagnostics: DiagnosticSink) {
        self.filePath = filePath
        self.converter = converter
        self.diagnostics = diagnostics
    }

    // MARK: - Entry point

    func collect(from sourceFile: SourceFileSyntax) {
        collect(statements: sourceFile.statements)
    }

    func makeSwiftFile() -> SwiftFile {
        // A nested type is finished before its enclosing type, so the arrays come out in
        // completion order. Sort by position to restore source order.
        SwiftFile(
            path: filePath,
            imports: imports,
            classes: inSourceOrder(classes),
            structs: inSourceOrder(structs),
            actors: inSourceOrder(actors),
            protocols: inSourceOrder(protocols),
            extensions: inSourceOrder(extensions),
            functions: topLevelFunctions,
            properties: topLevelProperties,
            enums: inSourceOrder(enums),
            typealiases: inSourceOrder(typealiases),
            macros: inSourceOrder(macros),
            operators: operators,
            precedenceGroups: precedenceGroups,
            diagnostics: diagnostics.diagnostics
        )
    }

    private func inSourceOrder<Declaration: SwiftDeclaration>(_ declarations: [Declaration]) -> [Declaration] {
        declarations.sorted {
            ($0.location.line, $0.location.column) < ($1.location.line, $1.location.column)
        }
    }

    // MARK: - Top level

    private func collect(statements: CodeBlockItemListSyntax) {
        for statement in statements {
            guard case .decl(let decl) = statement.item else { continue }
            collectTopLevel(decl)
        }
    }

    private func collectTopLevel(_ decl: DeclSyntax) {
        switch decl.as(DeclSyntaxEnum.self) {
        case .importDecl(let node):
            imports.append(makeImport(node))
        case .ifConfigDecl(let node):
            for clause in node.clauses {
                switch clause.elements {
                case .statements(let statements): collect(statements: statements)
                case .decls(let members):
                    for member in members { collectTopLevel(member.decl) }
                default: break
                }
            }
        case .operatorDecl(let node):
            operators.append(makeOperator(node))
        case .precedenceGroupDecl(let node):
            precedenceGroups.append(makePrecedenceGroup(node))
        case .functionDecl(let node):
            topLevelFunctions.append(makeFunction(node, parent: nil))
        case .variableDecl(let node):
            topLevelProperties.append(contentsOf: makeProperties(node, parent: nil))
        default:
            collectType(decl, parent: nil)
        }
    }

    /// Collects the declaration forms that can appear both at file scope and nested
    /// inside a type. Returns `false` when `decl` is not one of them.
    @discardableResult
    private func collectType(_ decl: DeclSyntax, parent: String?) -> Bool {
        switch decl.as(DeclSyntaxEnum.self) {
        case .classDecl(let node):
            classes.append(makeClass(node, parent: parent))
        case .structDecl(let node):
            structs.append(makeStruct(node, parent: parent))
        case .actorDecl(let node):
            actors.append(makeActor(node, parent: parent))
        case .enumDecl(let node):
            enums.append(makeEnum(node, parent: parent))
        case .protocolDecl(let node):
            protocols.append(makeProtocol(node, parent: parent))
        case .extensionDecl(let node):
            extensions.append(makeExtension(node, parent: parent))
        case .typeAliasDecl(let node):
            typealiases.append(makeTypealias(node, parent: parent))
        case .macroDecl(let node):
            macros.append(makeMacro(node, parent: parent))

        // Forms that carry no declaration of their own.
        case .macroExpansionDecl, .poundSourceLocation, .editorPlaceholderDecl, .missingDecl:
            return false

        default:
            diagnostics.unsupported(
                "\(decl.kind) is not modelled; the declarations it contains are not visible to rules",
                at: location(of: Syntax(decl))
            )
            return false
        }
        return true
    }

    // MARK: - Members

    /// Collected members of one container. Nested types are *not* here — they are
    /// appended to the file-level arrays as they are found, so their dependencies stay
    /// attached to themselves.
    private struct MemberSet {
        var properties: [SwiftPropertyDeclaration] = []
        var methods: [SwiftFunctionDeclaration] = []
        var subscripts: [SwiftSubscriptDeclaration] = []
        var deinitializers: [SwiftDeinitializerDeclaration] = []
        var associatedTypes: [SwiftAssociatedTypeDeclaration] = []
        var cases: [SwiftEnumDeclaration.EnumCase] = []
        var caseDependencies: [SwiftDependency] = []

        /// The dependencies the container inherits from its own members.
        var dependencies: [SwiftDependency] {
            var all: [SwiftDependency] = []
            all.append(contentsOf: properties.flatMap(\.dependencies))
            all.append(contentsOf: methods.flatMap(\.dependencies))
            all.append(contentsOf: subscripts.flatMap(\.dependencies))
            all.append(contentsOf: associatedTypes.flatMap(\.dependencies))
            all.append(contentsOf: caseDependencies)
            return all
        }
    }

    /// - Parameter genericParameters: names bound by the container's generic clause.
    ///   A reference to one of them is not a dependency on an outside type.
    private func members(
        of memberBlock: MemberBlockSyntax,
        owner: String,
        genericParameters: Set<String> = []
    ) -> MemberSet {
        var collected = MemberSet()
        collectMembers(memberBlock.members, into: &collected, owner: owner, genericParameters: genericParameters)
        return collected
    }

    private func collectMembers(
        _ items: MemberBlockItemListSyntax,
        into collected: inout MemberSet,
        owner: String,
        genericParameters: Set<String>
    ) {
        for item in items {
            let decl = item.decl
            switch decl.as(DeclSyntaxEnum.self) {
            case .variableDecl(let node):
                collected.properties.append(contentsOf: makeProperties(node, parent: owner))
            case .functionDecl(let node):
                collected.methods.append(makeFunction(node, parent: owner))
            case .initializerDecl(let node):
                collected.methods.append(makeInitializer(node, parent: owner))
            case .deinitializerDecl(let node):
                collected.deinitializers.append(makeDeinitializer(node, parent: owner))
            case .subscriptDecl(let node):
                collected.subscripts.append(makeSubscript(node, parent: owner))
            case .associatedTypeDecl(let node):
                collected.associatedTypes.append(makeAssociatedType(node, parent: owner))
            case .enumCaseDecl(let node):
                appendCases(from: node, into: &collected, genericParameters: genericParameters)
            case .ifConfigDecl(let node):
                for clause in node.clauses {
                    switch clause.elements {
                    case .decls(let nested):
                        collectMembers(nested, into: &collected, owner: owner, genericParameters: genericParameters)
                    case .statements(let statements):
                        collect(statements: statements)
                    default:
                        break
                    }
                }
            default:
                collectType(decl, parent: owner)
            }
        }
    }

    // MARK: - Containers

    private func makeClass(_ node: ClassDeclSyntax, parent: String?) -> SwiftClassDeclaration {
        let name = qualify(node.name.text, in: parent)
        var dependencies: [SwiftDependency] = []
        var superClass: String?
        var protocolNames: [String] = []

        if let inheritanceClause = node.inheritanceClause {
            for (index, inheritance) in inheritanceClause.inheritedTypes.enumerated() {
                let typeSyntax = Syntax(inheritance.type)
                let typeName = typeSyntax.trimmedDescription
                let depLocation = location(of: typeSyntax)

                // The first entry *may* be a superclass; without semantic analysis the
                // parser cannot tell a base class from a protocol.
                if index == 0 {
                    superClass = typeName
                    dependencies.append(contentsOf: dependenciesFor(typeName, kind: .inheritance, at: depLocation))
                } else {
                    protocolNames.append(typeName)
                    dependencies.append(contentsOf: dependenciesFor(typeName, kind: .conformance, at: depLocation))
                }
            }
        }

        let members = members(of: node.memberBlock, owner: name, genericParameters: genericNames(node.genericParameterClause))
        dependencies.append(contentsOf: members.dependencies)

        return SwiftClassDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            superClass: superClass,
            protocols: protocolNames,
            properties: members.properties,
            methods: members.methods,
            subscripts: members.subscripts,
            deinitializers: members.deinitializers,
            parentName: parent
        )
    }

    private func makeStruct(_ node: StructDeclSyntax, parent: String?) -> SwiftStructDeclaration {
        let name = qualify(node.name.text, in: parent)
        var dependencies: [SwiftDependency] = []
        let protocolNames = conformances(node.inheritanceClause, into: &dependencies)

        let members = members(of: node.memberBlock, owner: name, genericParameters: genericNames(node.genericParameterClause))
        dependencies.append(contentsOf: members.dependencies)

        return SwiftStructDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            protocols: protocolNames,
            properties: members.properties,
            methods: members.methods,
            subscripts: members.subscripts,
            parentName: parent
        )
    }

    private func makeActor(_ node: ActorDeclSyntax, parent: String?) -> SwiftActorDeclaration {
        let name = qualify(node.name.text, in: parent)
        var dependencies: [SwiftDependency] = []
        // An actor cannot inherit, so every inherited type is a conformance.
        let protocolNames = conformances(node.inheritanceClause, into: &dependencies)

        let members = members(of: node.memberBlock, owner: name, genericParameters: genericNames(node.genericParameterClause))
        dependencies.append(contentsOf: members.dependencies)

        return SwiftActorDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            protocols: protocolNames,
            properties: members.properties,
            methods: members.methods,
            subscripts: members.subscripts,
            deinitializers: members.deinitializers,
            parentName: parent
        )
    }

    private func makeEnum(_ node: EnumDeclSyntax, parent: String?) -> SwiftEnumDeclaration {
        let name = qualify(node.name.text, in: parent)
        var dependencies: [SwiftDependency] = []
        var protocolNames: [String] = []
        var rawType: String?

        if let inheritanceClause = node.inheritanceClause {
            for inheritance in inheritanceClause.inheritedTypes {
                let typeSyntax = Syntax(inheritance.type)
                let typeName = typeSyntax.trimmedDescription
                let depLocation = location(of: typeSyntax)

                let commonRawTypes = ["String", "Int", "UInt", "Float", "Double", "Character", "RawRepresentable"]
                if rawType == nil, commonRawTypes.contains(where: { typeName.hasPrefix($0) }) {
                    // A raw value and a conformance are spelled identically; assume the
                    // first entry that names a common raw type is the raw type.
                    rawType = typeName
                    dependencies.append(contentsOf: dependenciesFor(typeName, kind: .typeUsage, at: depLocation))
                } else {
                    protocolNames.append(typeName)
                    dependencies.append(contentsOf: dependenciesFor(typeName, kind: .conformance, at: depLocation))
                }
            }
        }

        let generics = genericNames(node.genericParameterClause)
        if let genericClause = node.genericParameterClause {
            for parameter in genericClause.parameters {
                guard let constraint = parameter.inheritedType else { continue }
                let typeSyntax = Syntax(constraint)
                dependencies.append(contentsOf: dependenciesFor(
                    typeSyntax.trimmedDescription,
                    kind: .conformance,
                    at: location(of: typeSyntax)
                ))
            }
        }

        let members = members(of: node.memberBlock, owner: name, genericParameters: generics)
        dependencies.append(contentsOf: members.dependencies)

        return SwiftEnumDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            cases: members.cases,
            properties: members.properties,
            methods: members.methods,
            rawType: rawType,
            protocols: protocolNames,
            subscripts: members.subscripts,
            parentName: parent
        )
    }

    private func makeProtocol(_ node: ProtocolDeclSyntax, parent: String?) -> SwiftProtocolDeclaration {
        let name = qualify(node.name.text, in: parent)
        var dependencies: [SwiftDependency] = []
        let inherited = conformances(node.inheritanceClause, into: &dependencies)

        let members = members(of: node.memberBlock, owner: name)
        dependencies.append(contentsOf: members.dependencies)

        return SwiftProtocolDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            inheritedProtocols: inherited,
            propertyRequirements: members.properties,
            methodRequirements: members.methods,
            subscriptRequirements: members.subscripts,
            associatedTypes: members.associatedTypes,
            parentName: parent
        )
    }

    private func makeExtension(_ node: ExtensionDeclSyntax, parent: String?) -> SwiftExtensionDeclaration {
        let name = node.extendedType.trimmedDescription
        var dependencies: [SwiftDependency] = []
        let protocolNames = conformances(node.inheritanceClause, into: &dependencies)

        let extendedSyntax = Syntax(node.extendedType)
        dependencies.append(contentsOf: dependenciesFor(
            extendedSyntax.trimmedDescription,
            kind: .extension,
            at: location(of: extendedSyntax)
        ))

        let members = members(of: node.memberBlock, owner: name)
        dependencies.append(contentsOf: members.dependencies)

        return SwiftExtensionDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            properties: members.properties,
            methods: members.methods,
            protocols: protocolNames,
            subscripts: members.subscripts,
            parentName: parent
        )
    }

    // MARK: - Leaf declarations

    private func makeImport(_ node: ImportDeclSyntax) -> SwiftImportDeclaration {
        var moduleName = ""
        var submodules: [String] = []

        if let first = node.path.first {
            moduleName = first.name.text
            if node.path.count > 1 {
                submodules = node.path.dropFirst().map { $0.name.text }
            }
        }

        let kind: SwiftImportDeclaration.ImportKind
        if node.importKindSpecifier != nil {
            kind = .typeOnly
        } else if !submodules.isEmpty {
            kind = .component
        } else {
            kind = .regular
        }

        return SwiftImportDeclaration(
            name: moduleName,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: [],
            filePath: filePath,
            location: location(of: Syntax(node)),
            kind: kind,
            submodules: submodules
        )
    }

    private func makeFunction(_ node: FunctionDeclSyntax, parent: String?) -> SwiftFunctionDeclaration {
        let parameterList = node.signature.parameterClause.parameters
        let dependencies = signatureDependencies(of: node.signature)

        return SwiftFunctionDeclaration(
            name: node.name.text,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            parameters: parameters(parameterList),
            returnType: node.signature.returnClause?.type.trimmedDescription,
            body: node.body?.trimmedDescription,
            effectSpecifiers: effectSpecifiers(of: node.signature),
            parentName: parent
        )
    }

    private func makeInitializer(_ node: InitializerDeclSyntax, parent: String?) -> SwiftFunctionDeclaration {
        SwiftFunctionDeclaration(
            name: "init",
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: signatureDependencies(of: node.signature),
            filePath: filePath,
            location: location(of: Syntax(node)),
            parameters: parameters(node.signature.parameterClause.parameters),
            returnType: nil,
            body: node.body?.trimmedDescription,
            effectSpecifiers: effectSpecifiers(of: node.signature),
            parentName: parent
        )
    }

    private func makeDeinitializer(_ node: DeinitializerDeclSyntax, parent: String?) -> SwiftDeinitializerDeclaration {
        SwiftDeinitializerDeclaration(
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: [],
            filePath: filePath,
            location: location(of: Syntax(node)),
            body: node.body?.trimmedDescription,
            parentName: parent
        )
    }

    private func makeSubscript(_ node: SubscriptDeclSyntax, parent: String?) -> SwiftSubscriptDeclaration {
        var dependencies: [SwiftDependency] = []
        let parameterList = node.parameterClause.parameters

        for parameter in parameterList {
            let typeSyntax = Syntax(parameter.type)
            dependencies.append(contentsOf: dependenciesFor(
                typeSyntax.trimmedDescription,
                kind: .typeUsage,
                at: location(of: typeSyntax)
            ))
        }

        let returnSyntax = Syntax(node.returnClause)
        dependencies.append(contentsOf: dependenciesFor(
            node.returnClause.type.trimmedDescription,
            kind: .typeUsage,
            at: location(of: returnSyntax)
        ))

        return SwiftSubscriptDeclaration(
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            parameters: parameters(parameterList),
            returnType: node.returnClause.type.trimmedDescription,
            accessors: accessorNames(node.accessorBlock),
            parentName: parent
        )
    }

    private func makeAssociatedType(_ node: AssociatedTypeDeclSyntax, parent: String?) -> SwiftAssociatedTypeDeclaration {
        var dependencies: [SwiftDependency] = []
        let inherited = conformances(node.inheritanceClause, into: &dependencies)

        var defaultType: String?
        if let initializer = node.initializer {
            let typeSyntax = Syntax(initializer.value)
            defaultType = typeSyntax.trimmedDescription
            dependencies.append(contentsOf: dependenciesFor(
                typeSyntax.trimmedDescription,
                kind: .typeUsage,
                at: location(of: typeSyntax)
            ))
        }

        return SwiftAssociatedTypeDeclaration(
            name: node.name.text,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            inheritedTypes: inherited,
            defaultType: defaultType,
            parentName: parent
        )
    }

    private func makeTypealias(_ node: TypeAliasDeclSyntax, parent: String?) -> SwiftTypealiasDeclaration {
        let aliasedSyntax = Syntax(node.initializer.value)
        let aliasedType = aliasedSyntax.trimmedDescription
        let generics = genericNames(node.genericParameterClause)

        // A generic parameter of the alias itself is not an outside dependency.
        let dependencies = dependenciesFor(aliasedType, kind: .typeUsage, at: location(of: aliasedSyntax))
            .filter { !generics.contains($0.name) }

        return SwiftTypealiasDeclaration(
            name: qualify(node.name.text, in: parent),
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: dependencies,
            filePath: filePath,
            location: location(of: Syntax(node)),
            aliasedType: aliasedType,
            genericParameters: generics.sorted(),
            parentName: parent
        )
    }

    private func makeMacro(_ node: MacroDeclSyntax, parent: String?) -> SwiftMacroDeclaration {
        SwiftMacroDeclaration(
            name: qualify(node.name.text, in: parent),
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: signatureDependencies(of: node.signature),
            filePath: filePath,
            location: location(of: Syntax(node)),
            parameters: parameters(node.signature.parameterClause.parameters),
            returnType: node.signature.returnClause?.type.trimmedDescription,
            definition: node.definition?.value.trimmedDescription,
            parentName: parent
        )
    }

    private func makeOperator(_ node: OperatorDeclSyntax) -> SwiftOperatorDeclaration {
        let fixity = SwiftOperatorDeclaration.Fixity(rawValue: node.fixitySpecifier.text) ?? .infix
        return SwiftOperatorDeclaration(
            name: node.name.text,
            // The fixity keyword is also surfaced as a modifier, so `withModifier(.infix)`
            // reaches operator declarations the same way it reaches `prefix func`.
            modifiers: [SwiftModifier(rawValue: node.fixitySpecifier.text)],
            annotations: [],
            dependencies: [],
            filePath: filePath,
            location: location(of: Syntax(node)),
            fixity: fixity,
            precedenceGroup: node.operatorPrecedenceAndTypes?.precedenceGroup.text
        )
    }

    private func makePrecedenceGroup(_ node: PrecedenceGroupDeclSyntax) -> SwiftPrecedenceGroupDeclaration {
        var associativity: String?
        var isAssignment = false
        var higherThan: [String] = []
        var lowerThan: [String] = []

        for attribute in node.groupAttributes {
            switch attribute {
            case .precedenceGroupRelation(let relation):
                let names = relation.precedenceGroups.map { $0.name.text }
                if relation.higherThanOrLowerThanLabel.text == "higherThan" {
                    higherThan.append(contentsOf: names)
                } else {
                    lowerThan.append(contentsOf: names)
                }
            case .precedenceGroupAssignment(let assignment):
                isAssignment = assignment.value.text == "true"
            case .precedenceGroupAssociativity(let value):
                associativity = value.value.text
            }
        }

        return SwiftPrecedenceGroupDeclaration(
            name: node.name.text,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: [],
            filePath: filePath,
            location: location(of: Syntax(node)),
            associativity: associativity,
            isAssignment: isAssignment,
            higherThan: higherThan,
            lowerThan: lowerThan
        )
    }

    private func makeProperties(_ node: VariableDeclSyntax, parent: String?) -> [SwiftPropertyDeclaration] {
        let declModifiers = modifiers(node.modifiers)
        let declAnnotations = annotations(node.attributes)
        var dependencies: [SwiftDependency] = []
        var properties: [SwiftPropertyDeclaration] = []

        for binding in node.bindings {
            // Destructuring patterns (`let (a, b) = pair`) name no single property.
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

            var type = "Any"
            var typeIsDeclared = false

            if let typeAnnotation = binding.typeAnnotation {
                let typeSyntax = Syntax(typeAnnotation.type)
                type = typeSyntax.trimmedDescription
                let resolved = dependenciesFor(type, kind: .typeUsage, at: location(of: typeSyntax))
                dependencies.append(contentsOf: resolved)
                typeIsDeclared = !resolved.isEmpty
            }

            let initialValue = binding.initializer?.value

            if !typeIsDeclared, let initializer = initialValue,
               let inferred = inferTypeName(from: initializer) {
                type = inferred
                dependencies.append(contentsOf: dependenciesFor(
                    inferred,
                    kind: .typeUsage,
                    at: location(of: Syntax(initializer))
                ))
            }

            properties.append(SwiftPropertyDeclaration(
                name: pattern.identifier.text,
                modifiers: declModifiers,
                annotations: declAnnotations,
                dependencies: dependencies,
                filePath: filePath,
                location: location(of: Syntax(pattern)),
                type: type,
                isComputed: binding.accessorBlock != nil,
                initialValue: initialValue?.trimmedDescription,
                parentName: parent
            ))
        }

        return properties
    }

    private func appendCases(
        from node: EnumCaseDeclSyntax,
        into collected: inout MemberSet,
        genericParameters: Set<String>
    ) {
        for element in node.elements {
            var associatedValues: [String]?

            if let parameterClause = element.parameterClause {
                associatedValues = []
                for parameter in parameterClause.parameters {
                    let typeSyntax = parameter.type
                    let typeName = typeSyntax.trimmedDescription
                    associatedValues?.append(typeName)

                    let depLocation = location(of: Syntax(typeSyntax))
                    collected.caseDependencies.append(contentsOf: dependenciesFor(
                        typeName,
                        kind: .typeUsage,
                        at: depLocation
                    ).filter { !genericParameters.contains($0.name) })
                }
            }

            collected.cases.append(SwiftEnumDeclaration.EnumCase(
                name: element.name.text,
                associatedValues: associatedValues,
                rawValue: element.rawValue?.value.trimmedDescription
            ))
        }
    }

    // MARK: - Shared extraction

    private func qualify(_ simpleName: String, in parent: String?) -> String {
        guard let parent else { return simpleName }
        return "\(parent).\(simpleName)"
    }

    private func location(of node: Syntax) -> SourceLocation {
        let position = node.startLocation(converter: converter)
        return SourceLocation(file: filePath, line: position.line, column: position.column)
    }

    private func genericNames(_ clause: GenericParameterClauseSyntax?) -> Set<String> {
        guard let clause else { return [] }
        return Set(clause.parameters.map { $0.name.text })
    }

    /// Records every inherited type as a conformance and returns the names as written.
    private func conformances(
        _ clause: InheritanceClauseSyntax?,
        into dependencies: inout [SwiftDependency]
    ) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.map { inheritance in
            let typeSyntax = Syntax(inheritance.type)
            let typeName = typeSyntax.trimmedDescription
            dependencies.append(contentsOf: dependenciesFor(
                typeName,
                kind: .conformance,
                at: location(of: typeSyntax)
            ))
            return typeName
        }
    }

    private func dependenciesFor(
        _ typeName: String?,
        kind: DependencyKind,
        at location: SourceLocation
    ) -> [SwiftDependency] {
        extractTypeNames(from: typeName).map {
            SwiftDependency(name: $0, kind: kind, location: location)
        }
    }

    private func signatureDependencies(of signature: FunctionSignatureSyntax) -> [SwiftDependency] {
        var dependencies: [SwiftDependency] = []

        for parameter in signature.parameterClause.parameters {
            let typeSyntax = Syntax(parameter.type)
            dependencies.append(contentsOf: dependenciesFor(
                typeSyntax.trimmedDescription,
                kind: .typeUsage,
                at: location(of: typeSyntax)
            ))
        }

        if let returnClause = signature.returnClause {
            dependencies.append(contentsOf: dependenciesFor(
                returnClause.type.trimmedDescription,
                kind: .typeUsage,
                at: location(of: Syntax(returnClause))
            ))
        }

        return dependencies
    }

    private func effectSpecifiers(
        of signature: FunctionSignatureSyntax
    ) -> SwiftFunctionDeclaration.FunctionEffectSpecifiers {
        let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
        let throwsSpecifier = signature.effectSpecifiers?.throwsClause?.throwsSpecifier
        let isRethrows = throwsSpecifier?.text == "rethrows"

        return SwiftFunctionDeclaration.FunctionEffectSpecifiers(
            isAsync: isAsync,
            isThrowing: throwsSpecifier != nil && !isRethrows,
            isRethrows: isRethrows
        )
    }

    private func accessorNames(_ block: AccessorBlockSyntax?) -> [String] {
        guard let block else { return [] }
        switch block.accessors {
        case .accessors(let list):
            return list.map { $0.accessorSpecifier.text }
        case .getter:
            // `subscript(i: Int) -> T { expression }` — an implicit getter.
            return ["get"]
        }
    }

    private func parameters(_ list: FunctionParameterListSyntax) -> [SwiftParameterDeclaration] {
        list.map { parameter in
            SwiftParameterDeclaration(
                name: parameter.secondName?.text ?? parameter.firstName.text,
                type: parameter.type.trimmedDescription,
                defaultValue: parameter.defaultValue?.value.trimmedDescription
            )
        }
    }

    private func modifiers(_ list: DeclModifierListSyntax?) -> [SwiftModifier] {
        guard let list else { return [] }
        // Never failable: an unrecognized keyword is preserved as `.unknown` rather than
        // dropped, so a declaration cannot look less restricted than it is.
        return list.map { SwiftModifier(rawValue: $0.name.text) }
    }

    func annotations(_ attributeList: AttributeListSyntax?) -> [SwiftAnnotation] {
        guard let attributeList else { return [] }
        var annotations: [SwiftAnnotation] = []

        for element in attributeList {
            guard let attribute = element.as(AttributeSyntax.self) else {
                // An `#if`-wrapped attribute list; the attributes inside are not modelled.
                continue
            }

            let name = attribute.attributeName.trimmedDescription
            var arguments: [String: String] = [:]

            if let args = attribute.arguments {
                switch args {
                case .argumentList(let elements):
                    for element in elements {
                        // Unlabelled arguments share the "_" key; the last one wins.
                        arguments[element.label?.text ?? "_"] = element.expression.trimmedDescription
                    }
                case .string(let literal):
                    arguments["_"] = literal.segments.trimmedDescription
                case .availability(let availability):
                    for argument in availability {
                        let syntax = Syntax(argument.argument)
                        guard syntax.is(PlatformVersionSyntax.self) else { continue }
                        let version = syntax.cast(PlatformVersionSyntax.self)
                        arguments[version.platform.text] = version.version?.trimmedDescription
                    }
                default:
                    diagnostics.unsupported(
                        "Arguments of @\(name) are not modelled (\(args.syntaxNodeType)); the attribute is recorded without them",
                        at: location(of: Syntax(attribute))
                    )
                }
            }

            annotations.append(SwiftAnnotation(name: name, arguments: arguments))
        }

        return annotations
    }

    /// Splits a written type into the capitalized identifiers it mentions.
    ///
    /// Deliberately syntactic: the parser has no type checker, so `[String: UserProfile]`
    /// yields `String` and `UserProfile` and nothing resolves them to modules.
    func extractTypeNames(from typeString: String?) -> Set<String> {
        guard let cleaned = typeString?.trimmingCharacters(in: .whitespacesAndNewlines) else { return [] }

        let baseTypes = cleaned
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.first?.isUppercase == true }

        return Set(baseTypes)
    }

    /// Best-effort type inference for `let x = Something()`, used when a binding has no
    /// written type annotation.
    private func inferTypeName(from expression: ExprSyntax) -> String? {
        if let call = expression.as(FunctionCallExprSyntax.self) {
            return inferTypeName(from: call.calledExpression)
        }
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            // `.shared` with no base carries no type information without a type checker.
            guard let base = memberAccess.base else { return nil }
            return inferTypeName(from: base)
        }
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            return name.first?.isUppercase == true ? name : nil
        }
        return nil
    }
}
