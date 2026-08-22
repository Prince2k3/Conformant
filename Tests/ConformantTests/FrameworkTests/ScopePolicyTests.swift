//
//  ScopePolicyTests.swift
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

/// Covers the guarantee that a scope which could not be built reports that fact instead of
/// coming back empty. An empty scope satisfies every rule, so silently returning one turns
/// a broken test setup into a green test run.
final class ScopePolicyTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ConformantScopePolicyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    @discardableResult
    private func write(_ source: String, to name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private var missingPath: String {
        root.appendingPathComponent("does-not-exist").path
    }

    private let brokenSource = """
    struct Broken {
        func thing( {
    }
    """

    // MARK: - Missing paths

    func testStrictScopeThrowsOnMissingDirectory() throws {
        XCTAssertThrowsError(try Conformant.scope(directory: missingPath)) { error in
            guard case ConformantError.pathDoesNotExist = error else {
                return XCTFail("Expected .pathDoesNotExist, got \(error)")
            }
        }
    }

    func testStrictScopeThrowsOnMissingFile() throws {
        XCTAssertThrowsError(try Conformant.scope(file: missingPath)) { error in
            guard case ConformantError.pathDoesNotExist = error else {
                return XCTFail("Expected .pathDoesNotExist, got \(error)")
            }
        }
    }

    func testLenientScopeReturnsEmptyForMissingDirectory() throws {
        let scope = try Conformant.scope(directory: missingPath, policy: .lenient)
        XCTAssertTrue(scope.isEmpty)
        XCTAssertTrue(scope.diagnostics.isEmpty)
    }

    func testWarningScopeRecordsMissingDirectoryWithoutThrowing() throws {
        let scope = try Conformant.scope(directory: missingPath, policy: .warning)
        XCTAssertTrue(scope.isEmpty)
        XCTAssertEqual(scope.diagnostics.count, 1)
        XCTAssertEqual(scope.diagnostics.first?.category, .unreadableFile)
    }

    // MARK: - Empty scopes

    func testStrictScopeThrowsWhenNoSwiftFilesAreFound() throws {
        try write("not swift", to: "README.md")

        XCTAssertThrowsError(try Conformant.scope(directory: root.path)) { error in
            guard case ConformantError.emptyScope = error else {
                return XCTFail("Expected .emptyScope, got \(error)")
            }
        }
    }

    func testLenientScopeAllowsAnEmptyResult() throws {
        try write("not swift", to: "README.md")

        let scope = try Conformant.scope(directory: root.path, policy: .lenient)
        XCTAssertTrue(scope.isEmpty)
    }

    // MARK: - Syntax errors

    func testStrictScopeThrowsOnSyntaxErrors() throws {
        try write("struct Fine {}", to: "Fine.swift")
        try write(brokenSource, to: "Broken.swift")

        XCTAssertThrowsError(try Conformant.scope(directory: root.path)) { error in
            guard case ConformantError.syntaxErrors(let diagnostics) = error else {
                return XCTFail("Expected .syntaxErrors, got \(error)")
            }
            XCTAssertFalse(diagnostics.isEmpty)
            XCTAssertTrue(diagnostics.allSatisfy { $0.category == .syntaxError })
            XCTAssertTrue(
                diagnostics.contains { $0.location.file.hasSuffix("Broken.swift") },
                "Diagnostics should point at the file that failed: \(diagnostics)"
            )
        }
    }

    func testWarningScopeKeepsGoodFilesAndReportsBadOnes() throws {
        try write("struct Fine {}", to: "Fine.swift")
        try write(brokenSource, to: "Broken.swift")

        let scope = try Conformant.scope(directory: root.path, policy: .warning)
        XCTAssertFalse(scope.isEmpty)
        XCTAssertTrue(scope.hasSyntaxErrors)
        XCTAssertEqual(scope.structs().map(\.name).sorted(), ["Broken", "Fine"])
    }

    func testLenientScopeDropsSyntaxDiagnostics() throws {
        try write(brokenSource, to: "Broken.swift")

        let scope = try Conformant.scope(directory: root.path, policy: .lenient)
        XCTAssertFalse(scope.hasSyntaxErrors)
        XCTAssertTrue(scope.diagnostics.filter { $0.category == .syntaxError }.isEmpty)
    }

    func testValidSourceProducesNoDiagnostics() throws {
        try write("import Foundation\n\nfinal class Service {}\n", to: "Service.swift")

        let scope = try Conformant.scope(directory: root.path)
        XCTAssertFalse(scope.hasSyntaxErrors)
        XCTAssertEqual(scope.diagnostics.errors.count, 0)
        XCTAssertEqual(scope.classes().count, 1)
    }

    // MARK: - Discovery

    func testScopeSkipsBuildArtifactDirectories() throws {
        let buildDirectory = root.appendingPathComponent(".build/checkouts/Other")
        try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        try "struct Vendored {}".write(
            to: buildDirectory.appendingPathComponent("Vendored.swift"),
            atomically: true, encoding: .utf8
        )
        try write("struct Mine {}", to: "Mine.swift")

        let scope = try Conformant.scope(directory: root.path)
        XCTAssertEqual(scope.structs().map(\.name), ["Mine"])
    }

    /// The previous implementation matched skipped directories by substring, so a directory
    /// merely *containing* "Products", such as "ProductsFeature", was dropped along with
    /// the source in it.
    func testScopeDoesNotSkipDirectoriesThatMerelyContainAnExcludedName() throws {
        let featureDirectory = root.appendingPathComponent("ProductsFeature")
        try FileManager.default.createDirectory(at: featureDirectory, withIntermediateDirectories: true)
        try "struct ProductList {}".write(
            to: featureDirectory.appendingPathComponent("ProductList.swift"),
            atomically: true, encoding: .utf8
        )

        let scope = try Conformant.scope(directory: root.path)
        XCTAssertEqual(scope.structs().map(\.name), ["ProductList"])
    }

    func testScopeFromFileParsesASingleFile() throws {
        let url = try write("enum Flag { case on, off }", to: "Flag.swift")

        let scope = try Conformant.scope(file: url.path)
        XCTAssertEqual(scope.files().count, 1)
        XCTAssertEqual(scope.enums().map(\.name), ["Flag"])
    }

    // MARK: - Architecture guard

    func testCheckArchitectureReportsAnEmptyScopeInsteadOfPassing() throws {
        let scope = try Conformant.scope(directory: root.path, policy: .lenient)
        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")
            rules.defineLayer(domain)
            rules.defineLayer(data)
            rules.add(domain.mustNotDependOn(data))
        }

        XCTAssertFalse(result.passed, "An empty scope must not report every rule as passing")
        XCTAssertEqual(result.scopeProblems.count, 1)
        XCTAssertTrue(result.violations.isEmpty, "Rules should not be evaluated at all")
    }

    func testCheckArchitectureReportsSyntaxErrorsInsteadOfPassing() throws {
        try write(brokenSource, to: "Broken.swift")
        let scope = try Conformant.scope(directory: root.path, policy: .warning)

        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            rules.defineLayer(domain)
            rules.add(domain.dependsOnNothing())
        }

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.scopeProblems.count, 1)
        XCTAssertTrue(result.scopeProblems[0].contains("failed to parse"))
    }

    func testCheckArchitecturePassesOnACleanScope() throws {
        try write("struct Model {}", to: "Model.swift")
        let scope = try Conformant.scope(directory: root.path)

        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "NoSuchLayer")
            rules.defineLayer(domain)
            rules.add(domain.dependsOnNothing())
        }

        XCTAssertTrue(result.passed, result.description)
    }
}
