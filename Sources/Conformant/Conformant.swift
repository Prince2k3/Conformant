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

//    declaration → import-declaration
//    declaration → constant-declaration // missing
//    declaration → variable-declaration
//    declaration → typealias-declaration // missing
//    declaration → function-declaration
//    declaration → enum-declaration
//    declaration → struct-declaration
//    declaration → class-declaration
//    declaration → actor-declaration // missing
//    declaration → protocol-declaration
//    declaration → initializer-declaration // missing
//    declaration → deinitializer-declaration // missing
//    declaration → extension-declaration
//    declaration → subscript-declaration // missing
//    declaration → macro-declaration // missing
//    declaration → operator-declaration // missing
//    declaration → precedence-group-declaration // missing

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
        return declarations
    }

    public func types() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func typesAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func classesAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func structsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func enumsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }
}
