//
//  DeterminismTests.swift
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

/// The same input has to produce the same output, every run.
///
/// Rules report the first declaration that breaks them, freezing writes violations into a
/// baseline that is diffed against the next run, and snapshots record extraction verbatim.
/// All three read the order of the lists the scope hands back, so an order that came from
/// which collection pass ran first, or from which core finished first now that files are
/// parsed in parallel, would show up as spurious churn in a baseline nobody changed.
final class DeterminismTests: XCTestCase {

    // MARK: - One declaration's dependencies

    func testEachBindingOfADeclarationKeepsItsOwnDependencies() {
        // `let a: Int, b: String` is two properties. `b` is a String and nothing else; a
        // rule forbidding `Int` should not fire on it.
        let file = SwiftSyntaxParser().parse(
            source: "struct Probe { let a: Int, b: String }",
            path: "Probe.swift"
        )
        let properties = file.structs.first?.properties ?? []

        XCTAssertEqual(properties.map(\.name), ["a", "b"])
        XCTAssertEqual(properties.first?.dependencies.map(\.name), ["Int"])
        XCTAssertEqual(properties.last?.dependencies.map(\.name), ["String"])
    }

    func testATypeNamedTwiceAtOnePositionIsOneDependency() {
        // Both sides of the dictionary are written at the same position, so the walker
        // reports `Int` twice. The declaration depends on `Int` once.
        let file = SwiftSyntaxParser().parse(
            source: "struct Probe { let counts: [Int: Int] }",
            path: "Probe.swift"
        )

        XCTAssertEqual(file.structs.first?.dependencies.map(\.name), ["Int"])
    }

    func testDependenciesAreOrderedByWhereTheyWereWritten() {
        let source = """
        struct Probe {
            func send(_ request: Request) {}
            let store: Store
            func load() -> Response { fatalError() }
        }
        """
        let file = SwiftSyntaxParser().parse(source: source, path: "Probe.swift")

        // Collection walks properties and methods separately; the result reads top to
        // bottom regardless.
        XCTAssertEqual(
            file.structs.first?.dependencies.map(\.name),
            ["Request", "Store", "Response"]
        )
    }

    func testNestingOrderSurvivesWithinOnePosition() {
        // Everything a written type contributes shares that type's position, so the tie is
        // broken by the order the type reads in, not alphabetically.
        let file = SwiftSyntaxParser().parse(
            source: "struct Probe { let value: Result<Zebra, Apple> }",
            path: "Probe.swift"
        )

        XCTAssertEqual(
            file.structs.first?.dependencies.map(\.name),
            ["Result", "Zebra", "Apple"]
        )
    }

    // MARK: - A scope's declarations

    func testDeclarationsAreOrderedByWhereTheyWereWritten() throws {
        let directory = try makeDirectory([
            "B.swift": "struct Second {}\nclass Third {}\n",
            "A.swift": "class First {}\nstruct Fourth {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        // A.swift sorts before B.swift, and within each file the kinds interleave.
        XCTAssertEqual(scope.declarations().map(\.name), ["First", "Fourth", "Second", "Third"])
    }

    func testTheSameDirectoryProducesTheSameScopeTwice() throws {
        // Enough files that parsing them in parallel actually uses more than one core.
        var files: [String: String] = [:]
        for index in 0..<40 {
            files["File\(index).swift"] = """
            import Foundation

            struct Model\(index) {
                let identifier: UUID
                func render() -> Widget\(index) { fatalError() }
            }

            extension Model\(index): Codable {}
            """
        }
        let directory = try makeDirectory(files)
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let first = try render(Conformant.scope(directory: directory))
        let second = try render(Conformant.scope(directory: directory))

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 40 * 3, "Every file should contribute its import, its struct, and its extension")
    }

    // MARK: - Helpers

    /// Everything about a scope that a rule or a frozen baseline can observe the order of.
    private func render(_ scope: Conformant) -> [String] {
        scope.declarations().map { declaration in
            let dependencies = declaration.dependencies
                .map { "\($0.name)/\($0.kind)@\($0.location.line):\($0.location.column)" }
                .joined(separator: ",")
            return "\(declaration.filePath)|\(declaration.name)|\(dependencies)"
        }
    }

    private func makeDirectory(_ files: [String: String]) throws -> String {
        let root = NSTemporaryDirectory() + "DeterminismTests_" + UUID().uuidString
        for (relativePath, contents) in files {
            let path = (root as NSString).appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
        }
        return root
    }
}
