//
//  ValueGenericsTests.swift
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

/// Value generics put an expression where the grammar used to allow only a type: the `3`
/// in `Vector<3>`, the count of `[3 of Pixel]`, the right-hand side of `where N == 3`.
///
/// A value is not something a file can depend on, so none of those positions may invent a
/// dependency, and none of them may swallow the type written beside them either.
final class ValueGenericsTests: XCTestCase {

    func testAValueGenericArgumentNamesNoType() throws {
        let dependencies = try dependenciesOfBoard("""
        struct Board {
            var cells: Grid<3, Tile>
        }
        """)

        XCTAssertEqual(dependencies, ["Grid", "Tile"])
    }

    func testAnInlineArrayNamesItsElement() throws {
        let dependencies = try dependenciesOfBoard("""
        struct Board {
            var pixels: [4 of Pixel]
        }
        """)

        XCTAssertEqual(dependencies, ["Pixel"])
    }

    func testAnInlineArrayCountWrittenAsANameIsKept() throws {
        let dependencies = try dependenciesOfBoard("""
        struct Board {
            var pixels: [Width of Pixel]
        }
        """)

        XCTAssertEqual(dependencies, ["Pixel", "Width"])
    }

    func testAValueSameTypeRequirementNamesNoType() throws {
        let dependencies = try dependenciesOfBoard("""
        struct Board {
            func rows<let N: Int>(_ grid: Grid<N, Tile>) where N == 3 {}
        }
        """)

        XCTAssertEqual(dependencies, ["Grid", "Int", "Tile"])
    }

    func testAValueGenericArgumentInACallNamesNoType() throws {
        let dependencies = try dependenciesOfBoard("""
        struct Board {
            func make() {
                _ = Grid<3, Tile>()
            }
        }
        """)

        XCTAssertEqual(dependencies, ["Grid", "Tile"])
    }

    // MARK: - Helpers

    /// The distinct names `Board` depends on, sorted so the assertions read as a set.
    private func dependenciesOfBoard(_ source: String) throws -> [String] {
        let root = NSTemporaryDirectory() + "ValueGenericsTests_" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }
        try source.write(toFile: root + "/Board.swift", atomically: true, encoding: .utf8)

        let scope = try Conformant.scope(directory: root)
        XCTAssertTrue(scope.diagnostics.errors.isEmpty, "\(scope.diagnostics.errors)")

        guard let board = scope.structs().first(where: { $0.name == "Board" }) else {
            XCTFail("Board not found")
            return []
        }
        return Set(board.dependencies.map(\.name)).sorted()
    }
}
