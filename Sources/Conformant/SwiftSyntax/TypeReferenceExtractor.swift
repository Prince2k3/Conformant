//
//  TypeReferenceExtractor.swift
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

/// Turns a written `TypeSyntax` into the named types it mentions.
///
/// This replaces splitting `trimmedDescription` on non-alphanumerics, which could not
/// tell `Swift.Int` from two unrelated types, invented a dependency for every capitalized
/// word inside a string literal or attribute, and had no way to know which names were
/// bound by an enclosing generic clause.
struct TypeReferenceExtractor {

    /// Names bound by enclosing generic parameter clauses, `associatedtype`
    /// declarations, and `Self`. A reference rooted at one of these is a placeholder,
    /// not a dependency, and is dropped.
    var boundNames: Set<String> = []

    /// Receives a warning for each type node kind the walker does not model, so a
    /// future grammar addition surfaces instead of quietly shrinking the dependency graph.
    let diagnostics: DiagnosticSink

    /// Location reported with those warnings.
    let location: SourceLocation

    /// The named types mentioned anywhere in `type`, in the order they were written,
    /// with placeholders bound in the current scope removed.
    func references(in type: TypeSyntax?) -> [TypeReference] {
        guard let type else { return [] }
        return walk(type, form: .plain).flatMap(\.flattened).filter { !isBound($0) }
    }

    /// Whether a reference is rooted at a name bound in the current scope. `Element` is
    /// bound by `struct Box<Element>`; so is `Element.ID`, because it names a member of
    /// the placeholder rather than a type of its own.
    private func isBound(_ reference: TypeReference) -> Bool {
        boundNames.contains(reference.rootName)
    }

    // MARK: - Walking

    private func walk(_ type: TypeSyntax, form: TypeReference.Form) -> [TypeReference] {
        switch type.as(TypeSyntaxEnum.self) {

        case .identifierType(let node):
            // `Any` is the empty constraint, not a type this file can depend on. `Self`
            // is filtered later, by the bound-name set the enclosing declaration installs.
            let name = node.name.text
            guard name != "Any" else { return [] }
            return [TypeReference(
                baseName: name,
                qualifiedName: name,
                moduleQualifier: nil,
                genericArguments: arguments(of: node.genericArgumentClause, form: .plain),
                form: form
            )]

        case .memberType(let node):
            // `A.B.C` is one name. Written that way it stays that way: splitting it would
            // invent a dependency on `A` that the source never expressed.
            let written = node.trimmedDescription
            let path = qualifiedPath(of: node)
            return [TypeReference(
                baseName: node.name.text,
                qualifiedName: path.isEmpty ? written : path,
                moduleQualifier: path.split(separator: ".").first.map(String.init),
                genericArguments: arguments(of: node.genericArgumentClause, form: .plain),
                form: form
            )]

        case .optionalType(let node):
            return walk(node.wrappedType, form: .optional)

        case .implicitlyUnwrappedOptionalType(let node):
            return walk(node.wrappedType, form: .optional)

        case .arrayType(let node):
            return walk(node.element, form: .array)

        case .dictionaryType(let node):
            return walk(node.key, form: .dictionary) + walk(node.value, form: .dictionary)

        case .functionType(let node):
            return node.parameters.flatMap { walk($0.type, form: .function) }
                + walk(node.returnClause.type, form: .function)

        case .tupleType(let node):
            // A one-element parenthesized type is just that type in parentheses.
            let elementForm: TypeReference.Form = node.elements.count == 1 ? form : .tuple
            return node.elements.flatMap { walk($0.type, form: elementForm) }

        case .compositionType(let node):
            return node.elements.flatMap { walk($0.type, form: .composition) }

        case .someOrAnyType(let node):
            let isAny = node.someOrAnySpecifier.text == "any"
            return walk(node.constraint, form: isAny ? .existential : .opaque)

        case .namedOpaqueReturnType(let node):
            // `<T> T` — the clause binds its own placeholders, which are not dependencies.
            var inner = self
            inner.boundNames.formUnion(node.genericParameterClause.parameters.map(\.name.text))
            return inner.walk(node.type, form: .opaque)

        case .metatypeType(let node):
            return walk(node.baseType, form: .metatype)

        case .attributedType(let node):
            // `@escaping`, `inout`, `borrowing`, `sending`, … all wrap a real type.
            return walk(node.baseType, form: form)

        case .packExpansionType(let node):
            return walk(node.repetitionPattern, form: .pack)

        case .packElementType(let node):
            return walk(node.pack, form: .pack)

        case .suppressedType(let node):
            return walk(node.type, form: .suppressed)

        case .classRestrictionType:
            // `protocol P: class` constrains, it does not depend on a type named `class`.
            return []

        case .missingType:
            // The file already carries a syntax-error diagnostic; adding one per hole
            // would bury it.
            return []
        }
    }

    private func arguments(
        of clause: GenericArgumentClauseSyntax?,
        form: TypeReference.Form
    ) -> [TypeReference] {
        guard let clause else { return [] }
        return clause.arguments.flatMap { walk($0.argument, form: form) }
    }

    /// Rebuilds `A.B.C` without generic clauses, so `Swift.Array<Int>.Index` reads as
    /// `Swift.Array.Index`. Returns `""` when the base is not itself a plain name.
    private func qualifiedPath(of node: MemberTypeSyntax) -> String {
        var components = [node.name.text]
        var base = node.baseType

        while true {
            if let identifier = base.as(IdentifierTypeSyntax.self) {
                components.append(identifier.name.text)
                break
            }
            if let member = base.as(MemberTypeSyntax.self) {
                components.append(member.name.text)
                base = member.baseType
                continue
            }
            // `[Int].Element`, `(A, B).Self` and friends have no dotted name to rebuild.
            diagnostics.unsupported(
                "Member type of \(base.trimmedDescription) is recorded by its written form; only its last component is resolvable",
                at: location
            )
            return ""
        }

        return components.reversed().joined(separator: ".")
    }
}
