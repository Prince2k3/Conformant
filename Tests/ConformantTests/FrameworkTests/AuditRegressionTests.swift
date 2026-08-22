//
//  AuditRegressionTests.swift
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

/// Regression tests for defects found during the code audit.
final class AuditRegressionTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempDirectory() -> String {
        let directory = NSTemporaryDirectory() + "AuditRegressionTests_" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return directory
    }

    private func write(_ source: String, to path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try? source.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Path canonicalization

    /// `FileManager`'s enumerator resolves symlinks, so on macOS a file created
    /// under `/var/folders/...` is reported as `/private/var/folders/...`.
    /// `inFile(_:)` must still match the path the caller supplied.
    func testInFileMatchesPathThroughSymlinkedDirectory() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let filePath = directory + "/Sample.swift"
        write("class Sample {}", to: filePath)

        let scope = try Conformant.scope(directory: directory)

        XCTAssertEqual(scope.declarations().inFile(filePath).count, 1,
                       "inFile should match the caller-supplied path")
        XCTAssertEqual(scope.declarations().inFile("/private" + filePath).count, 1,
                       "inFile should match the symlink-resolved path")
    }

    /// All three scope entry points must record the same path for the same file.
    func testScopeEntryPointsAgreeOnFilePath() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let filePath = directory + "/Sample.swift"
        write("class Sample {}", to: filePath)

        let fromDirectory = try Conformant.scope(directory: directory).classes().first?.filePath
        let fromFile = try Conformant.scope(file: filePath).classes().first?.filePath
        let fromProject = try Conformant.scope(project: directory).classes().first?.filePath

        XCTAssertNotNil(fromDirectory)
        XCTAssertEqual(fromDirectory, fromFile)
        XCTAssertEqual(fromDirectory, fromProject)
    }

    // MARK: - DependsOnNothingRule

    /// The rule previously compared `source.resideIn(declaration)` for
    /// declarations already filtered to that layer, so it could never fail.
    func testDependsOnNothingDetectsCrossLayerDependency() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        write("public class Presenter {}", to: directory + "/Presentation/Presenter.swift")
        write("""
        public class DomainService {
            private let presenter: Presenter
            public init(presenter: Presenter) { self.presenter = presenter }
        }
        """, to: directory + "/Domain/DomainService.swift")

        let scope = try Conformant.scope(directory: directory)
        let passed = scope.assertArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            rules.defineLayer(domain)
            rules.defineLayer(presentation)
            rules.add(domain.dependsOnNothing())
        }

        XCTAssertFalse(passed, "Domain depends on Presentation and must be reported")
    }

    /// Dependencies inside the same layer, and on types belonging to no declared
    /// layer, are not violations.
    func testDependsOnNothingAllowsIntraLayerAndUnknownDependencies() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        write("public struct DomainModel {}", to: directory + "/Domain/DomainModel.swift")
        write("""
        import Foundation

        public class DomainService {
            private let model: DomainModel
            private let identifier: UUID
            public init(model: DomainModel, identifier: UUID) {
                self.model = model
                self.identifier = identifier
            }
        }
        """, to: directory + "/Domain/DomainService.swift")
        write("public class Presenter {}", to: directory + "/Presentation/Presenter.swift")

        let scope = try Conformant.scope(directory: directory)
        let passed = scope.assertArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            rules.defineLayer(domain)
            rules.defineLayer(presentation)
            rules.add(domain.dependsOnNothing())
        }

        XCTAssertTrue(passed, "Same-layer and unlayered dependencies are allowed")
    }

    // MARK: - Layer ordering

    /// Layers were stored in a dictionary, so the layer that "won" for a
    /// declaration matching several predicates varied between runs.
    func testLayerEvaluationOrderFollowsDefinitionOrder() {
        let rules = ArchitectureRules()
        let names = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"]
        for name in names {
            rules.defineLayer(Layer(name: name, directory: name))
        }

        XCTAssertEqual(rules.layers.map(\.name), names)
    }

    func testRedefiningLayerKeepsItsPosition() {
        let rules = ArchitectureRules()
        rules.defineLayer(Layer(name: "Alpha", directory: "Alpha"))
        rules.defineLayer(Layer(name: "Beta", directory: "Beta"))
        rules.defineLayer(Layer(name: "Alpha", directory: "AlphaRenamed"))

        XCTAssertEqual(rules.layers.map(\.name), ["Alpha", "Beta"])
        XCTAssertNotNil(rules.layer("Alpha"))
    }

    // MARK: - Frozen violation baseline

    /// The baseline is meant to be committed, so its contents must not reorder
    /// between runs and its directory must be created on demand.
    func testFrozenBaselineIsStableAcrossRuns() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let baselinePath = directory + "/nested/baseline.json"
        let violations = (1...25).map {
            StoredViolation(filePath: "/src/File\($0).swift",
                            line: $0,
                            ruleDescription: "Rule",
                            detail: "Detail \($0)",
                            declarationName: "Type\($0)")
        }

        let store = FileViolationStore(filePath: baselinePath)
        store.saveViolations(violations.shuffled())
        let firstWrite = try? Data(contentsOf: URL(fileURLWithPath: baselinePath))

        store.saveViolations(violations.shuffled())
        let secondWrite = try? Data(contentsOf: URL(fileURLWithPath: baselinePath))

        XCTAssertNotNil(firstWrite, "The store should create missing directories")
        XCTAssertEqual(firstWrite, secondWrite, "Baseline bytes must not depend on input order")
        XCTAssertEqual(store.loadViolations().count, violations.count)
    }

    // MARK: - Type extraction

    /// `trimmedDescription` used to be shadowed by a local implementation that
    /// only trimmed whitespace, leaving trailing comments inside type names.
    func testTypeNamesExcludeSurroundingComments() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        write("""
        public struct Account {
            public let balance: Int // running total
        }
        """, to: directory + "/Account.swift")

        let scope = try Conformant.scope(directory: directory)
        let balance = scope.structs().first?.properties.first

        XCTAssertEqual(balance?.name, "balance")
        XCTAssertEqual(balance?.type, "Int", "The trailing comment must not leak into the type")
    }
}
