//
//  Conformant.swift
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

/// Represents a collection of Swift files to analyze.
///
/// Build a scope with one of the throwing `scope(...)` factories. They apply a
/// ``ScopePolicy`` so that an unreadable path, a file with syntax errors, or a scope that
/// matched nothing is reported instead of quietly producing a scope in which every rule
/// passes.
public struct Conformant {
    private let swiftFiles: [SwiftFile]

    /// Diagnostics gathered while building this scope: syntax errors, unreadable files, and
    /// warnings about constructs the extractor could not represent.
    public let diagnostics: [ParseDiagnostic]

    private init(swiftFiles: [SwiftFile], diagnostics: [ParseDiagnostic] = []) {
        self.swiftFiles = swiftFiles
        self.diagnostics = diagnostics
    }

    private init(_ result: ScopeBuilder.Result) {
        self.init(swiftFiles: result.files, diagnostics: result.diagnostics)
    }

    // MARK: - Scope construction

    /// Builds a scope from every Swift file under a project directory.
    ///
    /// - Throws: ``ConformantError`` when the policy says to fail on a missing path,
    ///   an unreadable file, a syntax error, or an empty result.
    public static func scope(
        project path: String = FileManager.default.currentDirectoryPath,
        policy: ScopePolicy = .strict
    ) throws -> Conformant {
        Conformant(try ScopeBuilder(policy: policy).build(directory: path))
    }

    /// Builds a scope from every Swift file under a directory.
    public static func scope(
        directory path: String,
        policy: ScopePolicy = .strict
    ) throws -> Conformant {
        Conformant(try ScopeBuilder(policy: policy).build(directory: path))
    }

    /// Builds a scope from a single Swift file.
    public static func scope(
        file path: String,
        policy: ScopePolicy = .strict
    ) throws -> Conformant {
        Conformant(try ScopeBuilder(policy: policy).build(file: path))
    }

    /// `true` when the scope holds no files. Rules evaluated against an empty scope all
    /// pass vacuously, so tests should treat this as a failure rather than a success.
    public var isEmpty: Bool {
        swiftFiles.isEmpty
    }

    /// `true` when any file in the scope failed to parse cleanly.
    public var hasSyntaxErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }

    // MARK: - Deprecated construction

    @available(*, deprecated, message: "Use scope(project:) — it reports parse failures instead of silently returning an empty scope.")
    public static func scopeFromProject(_ projectPath: String = FileManager.default.currentDirectoryPath) -> Conformant {
        (try? scope(project: projectPath, policy: .lenient)) ?? Conformant(swiftFiles: [])
    }

    @available(*, deprecated, message: "Use scope(directory:) — it reports parse failures instead of silently returning an empty scope.")
    public static func scopeFromDirectory(_ path: String) -> Conformant {
        (try? scope(directory: path, policy: .lenient)) ?? Conformant(swiftFiles: [])
    }

    @available(*, deprecated, message: "Use scope(file:) — it reports parse failures instead of silently returning an empty scope.")
    public static func scopeFromFile(path: String) -> Conformant {
        (try? scope(file: path, policy: .lenient)) ?? Conformant(swiftFiles: [])
    }

    // Query methods

    public func files() -> [SwiftFile] {
        return swiftFiles
    }

    /// Returns all import declarations in the scope
    public func imports() -> [SwiftImportDeclaration] {
        return files().flatMap { $0.imports }
    }

    /// Returns all imports of a specific module
    public func importsOf(_ module: String) -> [SwiftImportDeclaration] {
        return imports().filter { $0.isImportOf(module) }
    }

    /// Checks if any file in the scope imports the specified module
    public func hasImport(of module: String) -> Bool {
        return imports().contains { $0.isImportOf(module) }
    }

    public func classes() -> [SwiftClassDeclaration] {
        return files().flatMap { $0.classes }
    }

    public func structs() -> [SwiftStructDeclaration] {
        return files().flatMap { $0.structs }
    }

    public func protocols() -> [SwiftProtocolDeclaration] {
        return files().flatMap { $0.protocols }
    }

    public func extensions() -> [SwiftExtensionDeclaration] {
        return files().flatMap { $0.extensions }
    }

    public func functions() -> [SwiftFunctionDeclaration] {
        return files().flatMap { $0.functions }
    }

    public func properties() -> [SwiftPropertyDeclaration] {
        return files().flatMap { $0.properties }
    }

    public func enums() -> [SwiftEnumDeclaration] {
        return files().flatMap { $0.enums }
    }

    public func actors() -> [SwiftActorDeclaration] {
        return files().flatMap { $0.actors }
    }

    public func typealiases() -> [SwiftTypealiasDeclaration] {
        return files().flatMap { $0.typealiases }
    }

    public func macros() -> [SwiftMacroDeclaration] {
        return files().flatMap { $0.macros }
    }

    public func operators() -> [SwiftOperatorDeclaration] {
        return files().flatMap { $0.operators }
    }

    public func precedenceGroups() -> [SwiftPrecedenceGroupDeclaration] {
        return files().flatMap { $0.precedenceGroups }
    }

    /// Every initializer, method, and computed/stored property declared inside a type.
    ///
    /// Members are reached through their owning declaration; this is the flat view.
    public func subscripts() -> [SwiftSubscriptDeclaration] {
        var subscripts: [SwiftSubscriptDeclaration] = []
        subscripts.append(contentsOf: classes().flatMap { $0.subscripts })
        subscripts.append(contentsOf: structs().flatMap { $0.subscripts })
        subscripts.append(contentsOf: enums().flatMap { $0.subscripts })
        subscripts.append(contentsOf: actors().flatMap { $0.subscripts })
        subscripts.append(contentsOf: extensions().flatMap { $0.subscripts })
        subscripts.append(contentsOf: protocols().flatMap { $0.subscriptRequirements })
        return subscripts
    }

    public func deinitializers() -> [SwiftDeinitializerDeclaration] {
        var deinitializers: [SwiftDeinitializerDeclaration] = []
        deinitializers.append(contentsOf: classes().flatMap { $0.deinitializers })
        deinitializers.append(contentsOf: actors().flatMap { $0.deinitializers })
        return deinitializers
    }

    public func associatedTypes() -> [SwiftAssociatedTypeDeclaration] {
        return protocols().flatMap { $0.associatedTypes }
    }

    /// Types declared inside another type, named as they are written from the outside
    /// (`Outer.Inner`).
    public func nestedTypes() -> [AnySwiftDeclaration] {
        return types().filter { $0.isNested }
    }

    /// Types declared at file scope.
    public func topLevelTypes() -> [AnySwiftDeclaration] {
        return types().filter { !$0.isNested }
    }

// Every declaration form in the Swift grammar is extracted. Constants (`let`) are
// reported as properties, and initializers as methods named `init`, because that is how
// they are written and how rules reason about them.

    /// Orders a mixed list of declarations the way the source reads them.
    ///
    /// The lists above are assembled one kind at a time, so without this a file's structs
    /// would all precede its classes no matter where they were written. Rules report the
    /// first declaration they find and freezing stores baselines line by line, so the order
    /// is part of the output: the same files have to produce the same list every run.
    /// `name`, and then the position in the assembled list, break the tie for declarations
    /// that share a source position — a total order, so the result never depends on whether
    /// `sorted(by:)` happened to be stable.
    private func inSourceOrder(_ declarations: [AnySwiftDeclaration]) -> [AnySwiftDeclaration] {
        declarations.enumerated().sorted { lhs, rhs in
            if lhs.element.filePath != rhs.element.filePath { return lhs.element.filePath < rhs.element.filePath }
            let left = lhs.element.location, right = rhs.element.location
            if left.line != right.line { return left.line < right.line }
            if left.column != right.column { return left.column < right.column }
            if lhs.element.name != rhs.element.name { return lhs.element.name < rhs.element.name }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    public func declarations() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: imports().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: functions().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: properties().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: actors().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: typealiases().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: macros().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: operators().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: precedenceGroups().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: subscripts().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: deinitializers().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: associatedTypes().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }

    /// Nominal types: classes, structs, enums, protocols, and actors.
    public func types() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: actors().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }

    public func typesAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: actors().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }

    public func actorsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: actors().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }

    public func classesAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }

    public func structsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }

    public func enumsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return inSourceOrder(declarations)
    }
}
