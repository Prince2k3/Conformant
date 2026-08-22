//
//  LayeredProject.swift
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

import XCTest
@testable import Conformant

/// A project written to disk and parsed once, so a test can spend its lines on the
/// architecture it is describing rather than on file plumbing.
///
/// The architecture-style suites each write a small application laid out the way that
/// style prescribes, state the style's rules as layer rules, and assert both directions:
/// the clean layout passes, and a single misplaced dependency is reported — naming the
/// declaration that reached across the boundary and the dependency it reached for.
struct LayeredProject {
    let root: String
    let scope: Conformant

    /// Writes `files` — keyed by path relative to the project root — and parses them.
    static func write(
        _ files: [String: String],
        named name: String = "LayeredProject",
        policy: ScopePolicy = .strict
    ) throws -> LayeredProject {
        let root = NSTemporaryDirectory() + name + "_" + UUID().uuidString

        for (relativePath, contents) in files {
            let path = (root as NSString).appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
        }

        return LayeredProject(root: root, scope: try Conformant.scope(directory: root, policy: policy))
    }

    func remove() {
        try? FileManager.default.removeItem(atPath: root)
    }

    /// One rule's findings, rendered as `declaration -> dependency (kind)`.
    ///
    /// The rendering is what makes a wrong finding visible. A rule that reports the right
    /// number of violations for the wrong reason — the enclosing type instead of the one
    /// that reached, or an unrelated dependency of the same declaration — reads
    /// differently here, where a bare `XCTAssertFalse(passed)` could not tell them apart.
    func violations(
        of rule: ArchitectureRule,
        _ layers: [Layer],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [String] {
        var context = ArchitectureRuleContext(scope: scope, declarations: scope.declarations(), layers: layers)
        let passed = rule.check(context: &context)
        XCTAssertEqual(
            passed,
            rule.violations.isEmpty,
            "check() disagreed with its own violation list",
            file: file,
            line: line
        )
        return rule.violations.map {
            "\($0.sourceDeclaration.name) -> \($0.dependency.name) (\($0.dependency.kind))"
        }
    }

    /// Every rule below holds trivially over a layer that matched nothing, which is what a
    /// mistyped directory produces. A style suite asserts this before it trusts a pass.
    func assertEveryLayerIsPopulated(
        _ layers: [Layer],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let declarations = scope.declarations()
        for layer in layers {
            XCTAssertFalse(
                declarations.filter { layer.resideIn($0) }.isEmpty,
                "Layer '\(layer.name)' matched no declarations, so every rule about it passes vacuously",
                file: file,
                line: line
            )
        }
    }

    /// The names of the declarations a layer matched, sorted — for asserting that a layer
    /// caught what its author meant it to catch.
    func declarations(in layer: Layer) -> [String] {
        scope.declarations().filter { layer.resideIn($0) }.map(\.name).sorted()
    }
}

extension Layer {
    /// A layer that owns a directory and a module of the same name.
    ///
    /// Both halves matter: the directory decides which declarations are *in* the layer,
    /// and the module name decides whether another layer's `import` counts as reaching
    /// into it. A layer defined by directory alone silently ignores imports.
    static func directoryAndModule(_ name: String, directory: String? = nil) -> Layer {
        let directory = directory ?? name
        return Layer(name: name, modules: [name], predicate: { $0.filePath.contains("/\(directory)/") })
    }
}
