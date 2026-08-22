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
/// Conditional-compilation blocks are filtered only when the caller says which build to
/// read for. By default every `#if` branch is collected, because the parser has no build
/// configuration to evaluate them against — see `ScopePolicy.conditionalCompilation`.
final class DeclarationCollector {
    private let filePath: String
    private let converter: SourceLocationConverter
    let diagnostics: DiagnosticSink

    /// See `ScopePolicy.dependencyDepth`.
    private let dependencyDepth: ScopePolicy.DependencyDepth

    /// See `ScopePolicy.ignoresStandardLibraryTypes`.
    private let ignoresStandardLibraryTypes: Bool

    /// See `ScopePolicy.conditionalCompilation`.
    private let conditionalCompilation: ScopePolicy.ConditionalCompilation

    /// Type names bound by the declaration currently being walked — its generic
    /// parameters, the `associatedtype`s of the protocol it belongs to, and `Self`.
    /// A reference rooted at one of these names is a placeholder, not a dependency.
    private var boundNames: Set<String> = []

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

    init(
        filePath: String,
        converter: SourceLocationConverter,
        diagnostics: DiagnosticSink,
        dependencyDepth: ScopePolicy.DependencyDepth = .signaturesAndBodies,
        ignoresStandardLibraryTypes: Bool = false,
        conditionalCompilation: ScopePolicy.ConditionalCompilation = .allBranches
    ) {
        self.filePath = filePath
        self.converter = converter
        self.diagnostics = diagnostics
        self.dependencyDepth = dependencyDepth
        self.ignoresStandardLibraryTypes = ignoresStandardLibraryTypes
        self.conditionalCompilation = conditionalCompilation
    }

    /// The clauses of an `#if` whose declarations belong in the scope.
    ///
    /// Under `.allBranches` this is every clause, including the `#else`: declarations
    /// that could never coexist in one build are all collected, which is the safe
    /// direction for a rule to read.
    private func activeClauses(of node: IfConfigDeclSyntax) -> [IfConfigClauseSyntax] {
        guard case .activeBranch(let configuration) = conditionalCompilation else {
            return Array(node.clauses)
        }
        return ConditionalCompilationEvaluator(configuration: configuration).activeClauses(of: node)
    }

    /// Runs `body` with `names` added to the bound set, then restores it. Nesting is
    /// additive: a method's `<T>` joins, rather than replaces, its type's `<Element>`.
    private func binding<Result>(_ names: Set<String>, _ body: () -> Result) -> Result {
        guard !names.isEmpty else { return body() }
        let outer = boundNames
        boundNames.formUnion(names)
        defer { boundNames = outer }
        return body()
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
            for clause in activeClauses(of: node) {
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
            all.append(contentsOf: deinitializers.flatMap(\.dependencies))
            all.append(contentsOf: associatedTypes.flatMap(\.dependencies))
            all.append(contentsOf: caseDependencies)
            return all
        }
    }

    private func memberSet(of memberBlock: MemberBlockSyntax, owner: String) -> MemberSet {
        var collected = MemberSet()
        collectMembers(memberBlock.members, into: &collected, owner: owner)
        return collected
    }

    private func collectMembers(
        _ items: MemberBlockItemListSyntax,
        into collected: inout MemberSet,
        owner: String
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
                appendCases(from: node, into: &collected)
            case .ifConfigDecl(let node):
                for clause in activeClauses(of: node) {
                    switch clause.elements {
                    case .decls(let nested):
                        collectMembers(nested, into: &collected, owner: owner)
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

        let members: MemberSet = binding(scopeNames(node.genericParameterClause)) {
            if let inheritanceClause = node.inheritanceClause {
                for (index, inheritance) in inheritanceClause.inheritedTypes.enumerated() {
                    let typeName = inheritance.type.trimmedDescription
                    let depLocation = location(of: Syntax(inheritance.type))

                    // The first entry *may* be a superclass; without semantic analysis the
                    // parser cannot tell a base class from a protocol.
                    if index == 0 {
                        superClass = typeName
                        dependencies.append(contentsOf: typeDependencies(
                            on: inheritance.type, kind: .inheritance, at: depLocation
                        ))
                    } else {
                        protocolNames.append(typeName)
                        dependencies.append(contentsOf: typeDependencies(
                            on: inheritance.type, kind: .conformance, at: depLocation
                        ))
                    }
                }
            }
            dependencies.append(contentsOf: genericConstraints(
                node.genericParameterClause, node.genericWhereClause
            ))
            return memberSet(of: node.memberBlock, owner: name)
        }
        dependencies.append(contentsOf: members.dependencies)

        return SwiftClassDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
        var protocolNames: [String] = []

        let members: MemberSet = binding(scopeNames(node.genericParameterClause)) {
            protocolNames = conformances(node.inheritanceClause, into: &dependencies)
            dependencies.append(contentsOf: genericConstraints(
                node.genericParameterClause, node.genericWhereClause
            ))
            return memberSet(of: node.memberBlock, owner: name)
        }
        dependencies.append(contentsOf: members.dependencies)

        return SwiftStructDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
        var protocolNames: [String] = []

        let members: MemberSet = binding(scopeNames(node.genericParameterClause)) {
            // An actor cannot inherit, so every inherited type is a conformance.
            protocolNames = conformances(node.inheritanceClause, into: &dependencies)
            dependencies.append(contentsOf: genericConstraints(
                node.genericParameterClause, node.genericWhereClause
            ))
            return memberSet(of: node.memberBlock, owner: name)
        }
        dependencies.append(contentsOf: members.dependencies)

        return SwiftActorDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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

        let members: MemberSet = binding(scopeNames(node.genericParameterClause)) {
            if let inheritanceClause = node.inheritanceClause {
                for inheritance in inheritanceClause.inheritedTypes {
                    let typeName = inheritance.type.trimmedDescription
                    let depLocation = location(of: Syntax(inheritance.type))

                    let commonRawTypes = ["String", "Int", "UInt", "Float", "Double", "Character", "RawRepresentable"]
                    if rawType == nil, commonRawTypes.contains(where: { typeName.hasPrefix($0) }) {
                        // A raw value and a conformance are spelled identically; assume the
                        // first entry that names a common raw type is the raw type.
                        rawType = typeName
                        dependencies.append(contentsOf: typeDependencies(
                            on: inheritance.type, kind: .typeUsage, at: depLocation
                        ))
                    } else {
                        protocolNames.append(typeName)
                        dependencies.append(contentsOf: typeDependencies(
                            on: inheritance.type, kind: .conformance, at: depLocation
                        ))
                    }
                }
            }

            dependencies.append(contentsOf: genericConstraints(
                node.genericParameterClause, node.genericWhereClause
            ))

            return memberSet(of: node.memberBlock, owner: name)
        }
        dependencies.append(contentsOf: members.dependencies)

        return SwiftEnumDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
        var inherited: [String] = []

        // Associated types are bound for the whole protocol body, including requirements
        // written above the `associatedtype` that introduces them.
        let members: MemberSet = binding(associatedTypeNames(in: node.memberBlock).union(["Self"])) {
            inherited = conformances(node.inheritanceClause, into: &dependencies)
            dependencies.append(contentsOf: genericConstraints(nil, node.genericWhereClause))
            return memberSet(of: node.memberBlock, owner: name)
        }
        dependencies.append(contentsOf: members.dependencies)

        return SwiftProtocolDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
        var protocolNames: [String] = []

        // An extension cannot introduce generic parameters of its own, and the ones it
        // inherits from the extended type are invisible without a type checker: in
        // `extension Box { func first() -> Element }`, `Element` is still recorded as a
        // dependency.
        let members: MemberSet = binding(["Self"]) {
            protocolNames = conformances(node.inheritanceClause, into: &dependencies)
            dependencies.append(contentsOf: typeDependencies(
                on: node.extendedType,
                kind: .extension,
                at: location(of: Syntax(node.extendedType))
            ))
            dependencies.append(contentsOf: genericConstraints(nil, node.genericWhereClause))
            return memberSet(of: node.memberBlock, owner: name)
        }
        dependencies.append(contentsOf: members.dependencies)

        return SwiftExtensionDeclaration(
            name: name,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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

        // An import declaration depends on the module it names. Nothing else in the file
        // records that, so without this every module-level layer rule — and every filter
        // that asks for a dependency of kind `.import` — matched nothing at all.
        let dependency = SwiftDependency(
            name: moduleName,
            kind: .import,
            location: location(of: Syntax(node))
        )

        return SwiftImportDeclaration(
            name: moduleName,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: moduleName.isEmpty ? [] : [dependency],
            filePath: filePath,
            location: location(of: Syntax(node)),
            kind: kind,
            submodules: submodules
        )
    }

    private func makeFunction(_ node: FunctionDeclSyntax, parent: String?) -> SwiftFunctionDeclaration {
        let parameterList = node.signature.parameterClause.parameters
        let dependencies = binding(scopeNames(node.genericParameterClause)) {
            genericConstraints(node.genericParameterClause, node.genericWhereClause)
                + signatureDependencies(of: node.signature)
                + bodyDependencies(in: node.body)
        }

        return SwiftFunctionDeclaration(
            name: node.name.text,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
            dependencies: finalize(binding(scopeNames(node.genericParameterClause)) {
                genericConstraints(node.genericParameterClause, node.genericWhereClause)
                    + signatureDependencies(of: node.signature)
                    + bodyDependencies(in: node.body)
            }),
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
            dependencies: finalize(bodyDependencies(in: node.body)),
            filePath: filePath,
            location: location(of: Syntax(node)),
            body: node.body?.trimmedDescription,
            parentName: parent
        )
    }

    private func makeSubscript(_ node: SubscriptDeclSyntax, parent: String?) -> SwiftSubscriptDeclaration {
        var dependencies: [SwiftDependency] = []
        let parameterList = node.parameterClause.parameters

        binding(scopeNames(node.genericParameterClause)) {
            dependencies.append(contentsOf: genericConstraints(
                node.genericParameterClause, node.genericWhereClause
            ))

            for parameter in parameterList {
                dependencies.append(contentsOf: typeDependencies(
                    on: parameter.type,
                    kind: .typeUsage,
                    at: location(of: Syntax(parameter.type))
                ))
            }

            dependencies.append(contentsOf: typeDependencies(
                on: node.returnClause.type,
                kind: .typeUsage,
                at: location(of: Syntax(node.returnClause))
            ))

            dependencies.append(contentsOf: bodyDependencies(in: node.accessorBlock))
        }

        return SwiftSubscriptDeclaration(
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
            defaultType = initializer.value.trimmedDescription
            dependencies.append(contentsOf: typeDependencies(
                on: initializer.value,
                kind: .typeUsage,
                at: location(of: Syntax(initializer.value))
            ))
        }

        return SwiftAssociatedTypeDeclaration(
            name: node.name.text,
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
            filePath: filePath,
            location: location(of: Syntax(node)),
            inheritedTypes: inherited,
            defaultType: defaultType,
            parentName: parent
        )
    }

    private func makeTypealias(_ node: TypeAliasDeclSyntax, parent: String?) -> SwiftTypealiasDeclaration {
        let aliasedType = node.initializer.value.trimmedDescription
        let generics = genericNames(node.genericParameterClause)

        // A generic parameter of the alias itself is not an outside dependency.
        let dependencies = binding(generics) {
            genericConstraints(node.genericParameterClause, node.genericWhereClause)
                + typeDependencies(
                    on: node.initializer.value,
                    kind: .typeUsage,
                    at: location(of: Syntax(node.initializer.value))
                )
        }

        return SwiftTypealiasDeclaration(
            name: qualify(node.name.text, in: parent),
            modifiers: modifiers(node.modifiers),
            annotations: annotations(node.attributes),
            dependencies: finalize(dependencies),
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
            dependencies: finalize(binding(scopeNames(node.genericParameterClause)) {
                genericConstraints(node.genericParameterClause, node.genericWhereClause)
                    + signatureDependencies(of: node.signature)
            }),
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

    /// The final dependency list of one declaration: no duplicates, in source order.
    ///
    /// Collection walks a declaration in pieces — inheritance clause, generic constraints,
    /// signature, body, members — so the raw list is grouped by where it was found and can
    /// name the same type at the same position twice (`[Int: Int]` reports `Int` once per
    /// side). Callers read this list, freeze it into baselines, and diff it between runs,
    /// so the same input has to produce the same list every time.
    ///
    /// Two dependencies are the same when they agree on name, kind, and position — the key
    /// `SwiftDependency` already hashes on. The first one wins, which keeps the written form
    /// recorded by whichever pass saw the type most precisely.
    ///
    /// Everything a single written type contributes shares that type's position, so the sort
    /// falls back to the order the walker produced rather than to the name: `Result<T, E>`
    /// reads outside in, and alphabetising it would throw that structure away. Sorting on the
    /// index makes the fallback explicit instead of relying on `sorted(by:)` being stable.
    private func finalize(_ dependencies: [SwiftDependency]) -> [SwiftDependency] {
        var seen = Set<SwiftDependency>()
        var unique: [(index: Int, dependency: SwiftDependency)] = []
        unique.reserveCapacity(dependencies.count)
        for dependency in dependencies where seen.insert(dependency).inserted {
            unique.append((unique.count, dependency))
        }
        return unique.sorted { lhs, rhs in
            let left = lhs.dependency.location, right = rhs.dependency.location
            if left.line != right.line { return left.line < right.line }
            if left.column != right.column { return left.column < right.column }
            return lhs.index < rhs.index
        }.map(\.dependency)
    }

    private func makeProperties(_ node: VariableDeclSyntax, parent: String?) -> [SwiftPropertyDeclaration] {
        let declModifiers = modifiers(node.modifiers)
        let declAnnotations = annotations(node.attributes)
        var properties: [SwiftPropertyDeclaration] = []

        for binding in node.bindings {
            // Destructuring patterns (`let (a, b) = pair`) name no single property.
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

            // One list per binding: in `let a: Int, b: String`, `b` must not inherit `Int`.
            var dependencies: [SwiftDependency] = []
            var type = "Any"

            if let typeAnnotation = binding.typeAnnotation {
                type = typeAnnotation.type.trimmedDescription
                dependencies.append(contentsOf: typeDependencies(
                    on: typeAnnotation.type,
                    kind: .typeUsage,
                    at: location(of: Syntax(typeAnnotation.type))
                ))
            }

            let initialValue = binding.initializer?.value

            // Only guess when nothing was written: an annotation is the author's answer,
            // even when it resolves to no dependency at all (`let anything: Any`).
            if binding.typeAnnotation == nil, let initializer = initialValue,
               let inferred = inferTypeName(from: initializer) {
                type = inferred

                // With bodies read, the initializer is walked below and reports the same
                // name with more precision — `.instantiation` for `HTTPClient()` rather
                // than a guess. Recording both would double every inferred property.
                if dependencyDepth == .signatures {
                    dependencies.append(contentsOf: typeDependencies(
                        onInferredName: inferred,
                        kind: .typeUsage,
                        at: location(of: Syntax(initializer))
                    ))
                }
            }

            dependencies.append(contentsOf: bodyDependencies(in: initialValue))
            dependencies.append(contentsOf: bodyDependencies(in: binding.accessorBlock))

            properties.append(SwiftPropertyDeclaration(
                name: pattern.identifier.text,
                modifiers: declModifiers,
                annotations: declAnnotations,
                dependencies: finalize(dependencies),
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

    private func appendCases(from node: EnumCaseDeclSyntax, into collected: inout MemberSet) {
        for element in node.elements {
            var associatedValues: [String]?

            if let parameterClause = element.parameterClause {
                associatedValues = []
                for parameter in parameterClause.parameters {
                    associatedValues?.append(parameter.type.trimmedDescription)
                    collected.caseDependencies.append(contentsOf: typeDependencies(
                        on: parameter.type,
                        kind: .typeUsage,
                        at: location(of: Syntax(parameter.type))
                    ))
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

    /// The names a type declaration binds for its own body: its generic parameters plus
    /// `Self`, which names the declaration being written rather than a type it uses.
    private func scopeNames(_ clause: GenericParameterClauseSyntax?) -> Set<String> {
        genericNames(clause).union(["Self"])
    }

    /// The `associatedtype` names declared anywhere in a protocol body, including inside
    /// conditional-compilation blocks. Collected up front because a requirement may use
    /// an associated type declared below it.
    private func associatedTypeNames(in memberBlock: MemberBlockSyntax) -> Set<String> {
        var names: Set<String> = []

        func scan(_ items: MemberBlockItemListSyntax) {
            for item in items {
                switch item.decl.as(DeclSyntaxEnum.self) {
                case .associatedTypeDecl(let node):
                    names.insert(node.name.text)
                case .ifConfigDecl(let node):
                    for clause in activeClauses(of: node) {
                        if case .decls(let nested) = clause.elements { scan(nested) }
                    }
                default:
                    break
                }
            }
        }

        scan(memberBlock.members)
        return names
    }

    /// Records every inherited type as a conformance and returns the names as written.
    private func conformances(
        _ clause: InheritanceClauseSyntax?,
        into dependencies: inout [SwiftDependency]
    ) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.map { inheritance in
            dependencies.append(contentsOf: typeDependencies(
                on: inheritance.type,
                kind: .conformance,
                at: location(of: Syntax(inheritance.type))
            ))
            return inheritance.type.trimmedDescription
        }
    }

    /// The dependencies a written type expresses, in the order they were written.
    ///
    /// Names bound in the current scope are already gone by the time the extractor
    /// returns; the standard library filter and de-duplication happen here. Two mentions
    /// of the same type at the same location are one dependency — `(Int, Int)` is not a
    /// double dependency on `Int`.
    private func typeDependencies(
        on type: TypeSyntax?,
        kind: DependencyKind,
        at location: SourceLocation
    ) -> [SwiftDependency] {
        let extractor = TypeReferenceExtractor(
            boundNames: boundNames,
            diagnostics: diagnostics,
            location: location
        )
        return deduplicated(extractor.references(in: type), kind: kind, at: location)
    }

    /// Same, for a name recovered from an expression rather than a written type — there
    /// is no `TypeSyntax` to walk when the type comes from `let client = HTTPClient()`.
    private func typeDependencies(
        onInferredName name: String,
        kind: DependencyKind,
        at location: SourceLocation
    ) -> [SwiftDependency] {
        let reference = TypeReference(baseName: name, qualifiedName: name)
        guard !boundNames.contains(reference.rootName) else { return [] }
        return deduplicated([reference], kind: kind, at: location)
    }

    private func deduplicated(
        _ references: [TypeReference],
        kind: DependencyKind,
        at location: SourceLocation
    ) -> [SwiftDependency] {
        var seen: Set<String> = []
        var dependencies: [SwiftDependency] = []

        for reference in references {
            if ignoresStandardLibraryTypes, reference.isStandardLibraryType { continue }
            guard seen.insert(reference.qualifiedName).inserted else { continue }
            dependencies.append(SwiftDependency(
                name: reference.qualifiedName,
                kind: kind,
                location: location,
                reference: reference
            ))
        }

        return dependencies
    }

    /// What a body reaches for, when the policy asks for it.
    ///
    /// A body may mention the same type many times, so de-duplication here is by
    /// location as well as name: constructing a `URL` on two lines is two dependencies,
    /// and one construction seen once by two visitors is one.
    private func bodyDependencies<Node: SyntaxProtocol>(in node: Node?) -> [SwiftDependency] {
        guard dependencyDepth == .signaturesAndBodies, let node else { return [] }

        let walker = BodyDependencyCollector(
            boundNames: boundNames,
            diagnostics: diagnostics,
            converter: converter,
            filePath: filePath
        )
        walker.walk(node)

        var seen: Set<SwiftDependency> = []
        var dependencies: [SwiftDependency] = []

        for found in walker.found {
            if ignoresStandardLibraryTypes, found.reference.isStandardLibraryType { continue }
            let dependency = SwiftDependency(
                name: found.reference.qualifiedName,
                kind: found.kind,
                location: found.location,
                reference: found.reference
            )
            guard seen.insert(dependency).inserted else { continue }
            dependencies.append(dependency)
        }

        return dependencies
    }

    /// The bounds a declaration writes on its own generic parameters, including those in
    /// a `where` clause. `func send<T: Codable>(_ value: T)` depends on `Codable`: the
    /// parameter is a placeholder, but the requirement names a real type.
    private func genericConstraints(
        _ clause: GenericParameterClauseSyntax?,
        _ whereClause: GenericWhereClauseSyntax? = nil
    ) -> [SwiftDependency] {
        var dependencies: [SwiftDependency] = []

        func append(_ type: TypeSyntax) {
            dependencies.append(contentsOf: typeDependencies(
                on: type,
                kind: .genericConstraint,
                at: location(of: Syntax(type))
            ))
        }

        if let clause {
            for parameter in clause.parameters {
                guard let inherited = parameter.inheritedType else { continue }
                append(inherited)
            }
        }

        if let whereClause {
            for requirement in whereClause.requirements {
                switch requirement.requirement {
                case .conformanceRequirement(let node):
                    append(node.rightType)
                case .sameTypeRequirement(let node):
                    // Either side can be a value since value generics — `where N == 3`
                    // constrains a count, and a value names no type.
                    if case .type(let left) = node.leftType { append(left) }
                    if case .type(let right) = node.rightType { append(right) }
                case .layoutRequirement:
                    // `T: AnyObject`-style layout constraints name no type.
                    break
                }
            }
        }

        return dependencies
    }

    private func signatureDependencies(of signature: FunctionSignatureSyntax) -> [SwiftDependency] {
        var dependencies: [SwiftDependency] = []

        for parameter in signature.parameterClause.parameters {
            dependencies.append(contentsOf: typeDependencies(
                on: parameter.type,
                kind: .typeUsage,
                at: location(of: Syntax(parameter.type))
            ))
        }

        if let returnClause = signature.returnClause {
            dependencies.append(contentsOf: typeDependencies(
                on: returnClause.type,
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
