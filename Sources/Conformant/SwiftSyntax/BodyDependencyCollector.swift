//
//  BodyDependencyCollector.swift
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

/// Collects the types a body reaches for: what it instantiates, whose static members it
/// touches, and the types it writes down in annotations, casts, and call-site generic
/// arguments.
///
/// A signature says what a declaration promises; a body says what it actually depends on.
/// `func run() { UserRepository().load() }` couples to `UserRepository` as firmly as a
/// stored property would, and until this walker existed that coupling was invisible to
/// every architecture rule: the most common form of real coupling was the one form
/// Conformant could not see.
///
/// The walker is syntactic. It reports what was written, using Swift's own naming
/// convention to decide what reads as a type: a dotted chain's leading run of
/// capitalized components is the type, and the rest are members. So
/// `DatabaseClient.shared.fetch()` is a static access on `DatabaseClient`, and
/// `Notification.Name.didChange` is one on `Notification.Name`. An enum whose cases are
/// capitalized breaks that convention and will be read as a nested type.
final class BodyDependencyCollector: SyntaxVisitor {

    /// One type mention, before the standard library filter and de-duplication that the
    /// declaration collector applies.
    struct Found {
        let reference: TypeReference
        let kind: DependencyKind
        let location: SourceLocation
    }

    private(set) var found: [Found] = []

    /// Names bound by the enclosing declaration: its generic parameters, the
    /// `associatedtype`s of its protocol, and `Self`. `T()` inside `func make<T>()` is
    /// not a dependency on anything.
    private let boundNames: Set<String>
    private let diagnostics: DiagnosticSink
    private let converter: SourceLocationConverter
    private let filePath: String

    init(
        boundNames: Set<String>,
        diagnostics: DiagnosticSink,
        converter: SourceLocationConverter,
        filePath: String
    ) {
        self.boundNames = boundNames
        self.diagnostics = diagnostics
        self.converter = converter
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Expressions

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        record(callee: node.calledExpression)
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        // Only the outermost node of a chain is recorded. `A.b.c` is one mention of `A`,
        // and if it is being called the call handler has already claimed it.
        guard !isClaimedByAnEnclosingExpression(node) else { return .visitChildren }
        record(callee: ExprSyntax(node), calling: false)
        return .visitChildren
    }

    /// `Repository<User>()` mentions `User` as well as `Repository`, the same way the
    /// written type `Repository<User>` would.
    override func visit(_ node: GenericSpecializationExprSyntax) -> SyntaxVisitorContinueKind {
        for argument in node.genericArgumentClause.arguments {
            // A value generic, the `3` in `Vector<3>`, writes an expression here and
            // names no type.
            guard case .type(let type) = argument.argument else { continue }
            record(type: type)
        }
        return .visitChildren
    }

    // MARK: - Written types inside a body

    override func visit(_ node: TypeAnnotationSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        return .skipChildren
    }

    override func visit(_ node: TypeExprSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        return .skipChildren
    }

    override func visit(_ node: ReturnClauseSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        return .skipChildren
    }

    override func visit(_ node: AsExprSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        // The operand is still an expression worth walking.
        return .visitChildren
    }

    override func visit(_ node: IsExprSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        return .visitChildren
    }

    override func visit(_ node: IsTypePatternSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        return .skipChildren
    }

    override func visit(_ node: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
        if let type = node.type { record(type: type) }
        return .visitChildren
    }

    /// A function declared inside a body still has a signature.
    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        record(type: node.type)
        return .visitChildren
    }

    // MARK: - Recording

    private func record(type: TypeSyntax) {
        let location = location(of: Syntax(type))
        let extractor = TypeReferenceExtractor(
            boundNames: boundNames,
            diagnostics: diagnostics,
            location: location
        )
        for reference in extractor.references(in: type) {
            found.append(Found(reference: reference, kind: .typeUsage, location: location))
        }
    }

    private func record(callee: ExprSyntax, calling: Bool = true) {
        guard let all = components(of: callee), let split = split(all) else { return }

        // `URL.init(string:)` builds the same thing `URL(string:)` does.
        let namesTheTypeItself = split.members.isEmpty || split.members == ["init"]
        let kind: DependencyKind = calling && namesTheTypeItself ? .instantiation : .staticAccess

        guard let baseName = split.type.last else { return }
        let reference = TypeReference(
            baseName: baseName,
            qualifiedName: split.type.joined(separator: "."),
            moduleQualifier: split.type.count > 1 ? split.type[0] : nil,
            genericArguments: genericArguments(of: callee),
            form: .plain
        )
        guard !boundNames.contains(reference.rootName) else { return }

        found.append(Found(
            reference: reference,
            kind: kind,
            location: location(of: Syntax(callee))
        ))
    }

    // MARK: - Reading a dotted chain

    /// The identifiers a chain of member accesses spells, outermost last. `nil` when the
    /// chain is rooted in something other than a plain name: a literal, a subscript, a
    /// call, or the implicit base of `.someCase`.
    private func components(of expression: ExprSyntax) -> [String]? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return [reference.baseName.text]
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            guard let base = member.base, let prefix = components(of: base) else { return nil }
            return prefix + [member.declName.baseName.text]
        }
        if let specialization = expression.as(GenericSpecializationExprSyntax.self) {
            return components(of: specialization.expression)
        }
        return nil
    }

    /// Splits a chain into the type it names and the members reached on it, by Swift's
    /// capitalization convention. `nil` when nothing at the root reads as a type.
    private func split(_ all: [String]) -> (type: [String], members: [String])? {
        let typeCount = all.prefix { $0.first?.isUppercase == true }.count
        guard typeCount > 0 else { return nil }
        return (Array(all.prefix(typeCount)), Array(all.dropFirst(typeCount)))
    }

    private func genericArguments(of expression: ExprSyntax) -> [TypeReference] {
        guard let specialization = expression.as(GenericSpecializationExprSyntax.self) else {
            return []
        }
        let location = location(of: Syntax(specialization))
        let extractor = TypeReferenceExtractor(
            boundNames: boundNames,
            diagnostics: diagnostics,
            location: location
        )
        return specialization.genericArgumentClause.arguments.flatMap {
            extractor.references(in: $0.argument)
        }
    }

    /// Whether an enclosing expression already accounts for this member access: a longer
    /// chain it is the base of, a call that uses it as the callee, or a generic
    /// specialization of it.
    private func isClaimedByAnEnclosingExpression(_ node: MemberAccessExprSyntax) -> Bool {
        guard let parent = node.parent else { return false }
        if parent.is(MemberAccessExprSyntax.self) { return true }
        if parent.is(GenericSpecializationExprSyntax.self) { return true }
        if let call = parent.as(FunctionCallExprSyntax.self) {
            return call.calledExpression.id == ExprSyntax(node).id
        }
        return false
    }

    private func location(of node: Syntax) -> SourceLocation {
        let position = node.startLocation(converter: converter)
        return SourceLocation(file: filePath, line: position.line, column: position.column)
    }
}
