//
//  ImportDependencyTests.swift
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

/// Imports carry a dependency on the module they name.
///
/// Before they did, every module-level path in the library was dead: `imports()`,
/// `dependingOnModule(_:)`, `Layer.containsDependency`, and the module half of
/// `Layer(name:packageTarget:)` all looked for a dependency of kind `.import` that
/// nothing ever produced. A layer rule written against modules could not fail.
final class ImportDependencyTests: XCTestCase {

    // MARK: - The dependency itself

    func testAnImportDependsOnTheModuleItNames() {
        let file = SwiftSyntaxParser().parse(source: "import Foundation\n", path: "Probe.swift")

        let dependencies = file.imports.first?.dependencies ?? []
        XCTAssertEqual(dependencies.count, 1)
        XCTAssertEqual(dependencies.first?.name, "Foundation")
        XCTAssertEqual(dependencies.first?.kind, .import)
        XCTAssertEqual(dependencies.first?.location.line, 1, "The dependency should point at the import, not at the file")
    }

    func testASubmoduleImportDependsOnItsRootModule() {
        // `import Deep.Nested` reaches for the module `Deep`; the rest is a path inside
        // it, and a layer is defined by module names.
        let file = SwiftSyntaxParser().parse(source: "import Deep.Nested.Module\n", path: "Probe.swift")

        XCTAssertEqual(file.imports.first?.dependencies.map(\.name), ["Deep"])
        XCTAssertEqual(file.imports.first?.submodules, ["Nested", "Module"])
    }

    func testEveryFormOfImportCarriesItsModule() {
        let source = """
        import Foundation
        @testable import MyModule
        @_exported import Shared
        import struct Combine.Published
        """
        let file = SwiftSyntaxParser().parse(source: source, path: "Probe.swift")

        XCTAssertEqual(
            file.imports.map { $0.dependencies.map(\.name) },
            [["Foundation"], ["MyModule"], ["Shared"], ["Combine"]]
        )
    }

    // MARK: - Filtering

    func testDeclarationsCanBeFilteredByModule() throws {
        let directory = try makeDirectory([
            "Reader.swift": "import Persistence\nstruct Reader {}\n",
            "Renderer.swift": "import SwiftUI\nstruct Renderer {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        XCTAssertEqual(Set(scope.declarations().imports().map(\.name)), ["Persistence", "SwiftUI"])
        XCTAssertEqual(scope.declarations().dependingOnModule("Persistence").map(\.name), ["Persistence"])
        XCTAssertTrue(scope.declarations().dependingOnModule("CoreData").isEmpty)
    }

    // MARK: - Layer rules

    func testAModuleLayerIsReachedByAnImport() throws {
        let directory = try makeDirectory([
            "Domain/UseCase.swift": "import Persistence\nstruct GetUser {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            let persistence = Layer(name: "Persistence", modules: ["Persistence"]) { _ in false }
            rules.defineLayer(domain)
            rules.defineLayer(persistence)
            rules.add(domain.mustNotDependOn(persistence))
        }

        XCTAssertFalse(result.passed, "Importing Persistence from Domain is exactly what the rule forbids")
        XCTAssertEqual(result.violations.count, 1)
        XCTAssertTrue(
            result.violations[0].contains("forbidden layer 'Persistence'"),
            "Unexpected violation text: \(result.violations[0])"
        )
    }

    func testAModuleLayerThatIsNotImportedIsNotReached() throws {
        let directory = try makeDirectory([
            "Domain/UseCase.swift": "import Foundation\nstruct GetUser {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            let persistence = Layer(name: "Persistence", modules: ["Persistence"]) { _ in false }
            rules.defineLayer(domain)
            rules.defineLayer(persistence)
            rules.add(domain.mustNotDependOn(persistence))
        }

        XCTAssertTrue(result.passed, "Unexpected violations: \(result.violations)")
    }

    func testDependsOnNothingSeesImports() throws {
        let directory = try makeDirectory([
            "Domain/UseCase.swift": "import Persistence\nstruct GetUser {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", directory: "Domain")
            rules.defineLayer(domain)
            rules.defineLayer(Layer(name: "Persistence", modules: ["Persistence"]) { _ in false })
            rules.add(domain.dependsOnNothing())
        }

        XCTAssertFalse(result.passed, "The import is a dependency on another layer")
    }

    func testOnlyDependsOnAllowsAPermittedModule() throws {
        let directory = try makeDirectory([
            "Presentation/View.swift": "import Domain\nstruct UserView {}\n",
            "Presentation/Editor.swift": "import Persistence\nstruct UserEditor {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        let result = scope.checkArchitecture { rules in
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            let domain = Layer(name: "Domain", modules: ["Domain"]) { _ in false }
            let persistence = Layer(name: "Persistence", modules: ["Persistence"]) { _ in false }
            rules.defineLayer(presentation)
            rules.defineLayer(domain)
            rules.defineLayer(persistence)
            rules.add(presentation.onlyDependsOn(domain))
        }

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.violations.count, 1, "Only the Persistence import is out of bounds: \(result.violations)")
        XCTAssertTrue(result.violations[0].contains("Persistence"), result.violations[0])
    }

    @MainActor
    func testAPackageTargetLayerIsReachedByAnImport() throws {
        // `Layer(name:packageTarget:)` names a module *and* a source directory. The
        // module half was unreachable until imports carried a dependency.
        let directory = try makeDirectory([
            "Package.swift": """
            // swift-tools-version:6.1
            import PackageDescription
            let package = Package(
                name: "Demo",
                targets: [.target(name: "Persistence"), .target(name: "Domain")]
            )
            """,
            "Sources/Domain/UseCase.swift": "import Persistence\nstruct GetUser {}\n",
            "Sources/Persistence/Store.swift": "struct Store {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        let result = scope.checkArchitecture { rules in
            let domain = Layer(name: "Domain", packageTarget: "Domain")
            let persistence = Layer(name: "Persistence", packageTarget: "Persistence")
            rules.defineLayer(domain)
            rules.defineLayer(persistence)
            rules.add(domain.mustNotDependOn(persistence))
        }

        XCTAssertFalse(result.passed, "Domain imports the Persistence target")
    }

    func testAModuleAndATypeOfTheSameNameResolveSeparately() throws {
        // Both dependencies are named "Domain": one is `import Domain`, the other is a
        // property of type `Domain`. They resolve by different rules — module membership
        // versus where the declaration lives — so answering one with the other would
        // report a violation against whichever was looked up second.
        let directory = try makeDirectory([
            "Presentation/View.swift": "import Domain\nstruct UserView { let model: Domain }\n",
            "Core/Domain.swift": "struct Domain {}\n"
        ])
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        let result = scope.checkArchitecture { rules in
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            let core = Layer(name: "Core", directory: "Core")
            let domainModule = Layer(name: "DomainModule", modules: ["Domain"]) { _ in false }
            rules.defineLayer(presentation)
            rules.defineLayer(core)
            rules.defineLayer(domainModule)
            // The type lives in Core, which Presentation is allowed to reach. Only the
            // module is forbidden.
            rules.add(presentation.mustNotDependOn(domainModule))
        }

        XCTAssertFalse(result.passed)
        XCTAssertEqual(
            result.violations.count, 1,
            "The struct named Domain is in Core and should not be reported: \(result.violations)"
        )
        XCTAssertFalse(
            result.violations[0].contains("UserView"),
            "The reported violation should be the import, not the property typed `Domain`: \(result.violations[0])"
        )
    }

    // MARK: - Helpers

    private func makeDirectory(_ files: [String: String]) throws -> String {
        let root = NSTemporaryDirectory() + "ImportDependencyTests_" + UUID().uuidString
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
