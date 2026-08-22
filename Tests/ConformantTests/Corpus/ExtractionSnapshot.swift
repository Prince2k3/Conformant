//
//  ExtractionSnapshot.swift
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
@testable import Conformant

/// Renders a parsed `SwiftFile` as canonical text.
///
/// The rendering is the contract the corpus pins. It is deliberately verbose — every
/// field the extractor populates appears, so a change anywhere in the parser surfaces
/// as a reviewable diff instead of a silent behavioral shift. Ordering is stabilized
/// (declarations by source position, dependencies sorted) so the output depends only on
/// the input, never on dictionary or set iteration order.
enum ExtractionSnapshot {

    static func render(_ file: SwiftFile, fixtureName: String) -> String {
        var out: [String] = []
        out.append("fixture: \(fixtureName)")
        out.append("")

        section(&out, "imports", file.imports.map(renderImport))
        section(&out, "classes", file.classes.map(renderClass))
        section(&out, "structs", file.structs.map(renderStruct))
        section(&out, "enums", file.enums.map(renderEnum))
        section(&out, "protocols", file.protocols.map(renderProtocol))
        section(&out, "extensions", file.extensions.map(renderExtension))
        section(&out, "top-level functions", file.functions.map { renderFunction($0, indent: 0) })
        section(&out, "top-level properties", file.properties.map { renderProperty($0, indent: 0) })

        return out.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    // MARK: - Sections

    private static func section(_ out: inout [String], _ title: String, _ entries: [String]) {
        out.append("## \(title) (\(entries.count))")
        if entries.isEmpty {
            out.append("  <none>")
        } else {
            out.append(contentsOf: entries)
        }
        out.append("")
    }

    // MARK: - Declarations

    private static func renderImport(_ decl: SwiftImportDeclaration) -> String {
        var lines = ["- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        lines.append("    kind: \(decl.kind)")
        lines.append("    fullPath: \(decl.fullPath)")
        lines.append("    submodules: \(list(decl.submodules))")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies))
        return lines.joined(separator: "\n")
    }

    private static func renderClass(_ decl: SwiftClassDeclaration) -> String {
        var lines = ["- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        lines.append("    superclass: \(decl.superClass ?? "<none>")")
        lines.append("    protocols: \(list(decl.protocols))")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies))
        lines.append(contentsOf: members(decl.properties, decl.methods))
        return lines.joined(separator: "\n")
    }

    private static func renderStruct(_ decl: SwiftStructDeclaration) -> String {
        var lines = ["- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        lines.append("    protocols: \(list(decl.protocols))")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies))
        lines.append(contentsOf: members(decl.properties, decl.methods))
        return lines.joined(separator: "\n")
    }

    private static func renderEnum(_ decl: SwiftEnumDeclaration) -> String {
        var lines = ["- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        lines.append("    rawType: \(decl.rawType ?? "<none>")")
        lines.append("    protocols: \(list(decl.protocols))")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies))
        lines.append("    cases:")
        if decl.cases.isEmpty {
            lines.append("      <none>")
        } else {
            for enumCase in decl.cases {
                let associated = enumCase.associatedValues.map { "(\($0.joined(separator: ", ")))" } ?? ""
                let raw = enumCase.rawValue.map { " = \($0)" } ?? ""
                lines.append("      - \(enumCase.name)\(associated)\(raw)")
            }
        }
        lines.append(contentsOf: members(decl.properties, decl.methods))
        return lines.joined(separator: "\n")
    }

    private static func renderProtocol(_ decl: SwiftProtocolDeclaration) -> String {
        var lines = ["- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        lines.append("    inherits: \(list(decl.inheritedProtocols))")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies))
        lines.append(contentsOf: members(decl.propertyRequirements, decl.methodRequirements))
        return lines.joined(separator: "\n")
    }

    private static func renderExtension(_ decl: SwiftExtensionDeclaration) -> String {
        var lines = ["- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        lines.append("    protocols: \(list(decl.protocols))")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies))
        lines.append(contentsOf: members(decl.properties, decl.methods))
        return lines.joined(separator: "\n")
    }

    // MARK: - Members

    private static func members(
        _ properties: [SwiftPropertyDeclaration],
        _ methods: [SwiftFunctionDeclaration]
    ) -> [String] {
        var lines: [String] = []
        lines.append("    properties:")
        lines.append(contentsOf: properties.isEmpty
            ? ["      <none>"]
            : properties.map { renderProperty($0, indent: 6) })
        lines.append("    methods:")
        lines.append(contentsOf: methods.isEmpty
            ? ["      <none>"]
            : methods.map { renderFunction($0, indent: 6) })
        return lines
    }

    private static func renderProperty(_ decl: SwiftPropertyDeclaration, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        var lines = ["\(pad)- \(decl.name): \(decl.type) @\(decl.location.line):\(decl.location.column)"]
        lines.append("\(pad)    computed: \(decl.isComputed)")
        lines.append("\(pad)    initialValue: \(decl.initialValue ?? "<none>")")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies, pad: pad))
        return lines.joined(separator: "\n")
    }

    private static func renderFunction(_ decl: SwiftFunctionDeclaration, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        var lines = ["\(pad)- \(decl.name) @\(decl.location.line):\(decl.location.column)"]
        let parameters = decl.parameters.map { parameter -> String in
            let defaultValue = parameter.defaultValue.map { " = \($0)" } ?? ""
            return "\(parameter.name): \(parameter.type)\(defaultValue)"
        }
        lines.append("\(pad)    parameters: \(list(parameters))")
        lines.append("\(pad)    returns: \(decl.returnType ?? "<none>")")
        let effects = decl.effectSpecifiers
        lines.append("\(pad)    effects: async=\(effects.isAsync) throws=\(effects.isThrowing) rethrows=\(effects.isRethrows)")
        lines.append("\(pad)    hasBody: \(decl.body != nil)")
        lines.append(contentsOf: common(decl.modifiers, decl.annotations, decl.dependencies, pad: pad))
        return lines.joined(separator: "\n")
    }

    // MARK: - Shared fields

    private static func common(
        _ modifiers: [SwiftModifier],
        _ annotations: [SwiftAnnotation],
        _ dependencies: [SwiftDependency],
        pad: String = ""
    ) -> [String] {
        var lines: [String] = []
        lines.append("\(pad)    modifiers: \(list(modifiers.map(\.rawValue)))")
        lines.append("\(pad)    annotations: \(list(annotations.map(renderAnnotation)))")
        lines.append("\(pad)    dependencies: \(list(dependencies.map(renderDependency).sorted()))")
        return lines
    }

    private static func renderAnnotation(_ annotation: SwiftAnnotation) -> String {
        guard !annotation.arguments.isEmpty else { return "@\(annotation.name)" }
        // Sort by key: the arguments dictionary has no inherent order.
        let arguments = annotation.arguments
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        return "@\(annotation.name)(\(arguments))"
    }

    /// Dependency locations are rendered as line:column only — the absolute file path
    /// varies per machine and would make snapshots unshareable.
    private static func renderDependency(_ dependency: SwiftDependency) -> String {
        "\(dependency.name)/\(dependency.kind)@\(dependency.location.line):\(dependency.location.column)"
    }

    private static func list(_ values: [String]) -> String {
        values.isEmpty ? "[]" : "[\(values.joined(separator: ", "))]"
    }
}
