//
//  LayerRuleTests.swift
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

/// What a layer rule reports, not just whether it passed.
///
/// A rule that fails is only useful if it fails for the right reason: naming the
/// declaration that reached across the boundary and the dependency it reached for. A rule
/// that passes is only useful if it looked at anything at all. Both halves are asserted
/// here against one fixed four-layer project, with a single file injected per test, so
/// every reported violation has exactly one cause.
///
/// The style suites — MVC, MVVM, Clean, DDD, VIPER, Hexagonal — describe whole
/// architectures on top of these mechanics.
final class LayerRuleTests: XCTestCase {

    // MARK: - The clean project

    func testTheCleanProjectSatisfiesEveryRule() throws {
        let project = try makeProject()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.domain.dependsOnNothing())
            rules.add(layers.core.dependsOnNothing())
            rules.add(layers.data.onlyDependsOn(layers.domain, layers.core))
            rules.add(layers.presentation.onlyDependsOn(layers.domain, layers.core))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    // MARK: - Every kind of dependency a rule has to catch

    func testATypeWrittenInASignatureIsReported() throws {
        XCTAssertEqual(
            try violationsOfDomainDependsOnNothing(injecting: """
            public struct Broken {
                private let viewModel: UserViewModel
            }
            """),
            ["Broken -> UserViewModel (typeUsage)"]
        )
    }

    func testATypeConstructedInABodyIsReported() throws {
        XCTAssertEqual(
            try violationsOfDomainDependsOnNothing(injecting: """
            public struct Broken {
                public func build() {
                    _ = UserViewModel()
                }
            }
            """),
            ["Broken -> UserViewModel (instantiation)"]
        )
    }

    func testAStaticMemberReachedInABodyIsReported() throws {
        XCTAssertEqual(
            try violationsOfDomainDependsOnNothing(injecting: """
            public struct Broken {
                public func now() {
                    _ = Clock.shared
                }
            }
            """),
            ["Broken -> Clock (staticAccess)"]
        )
    }

    func testABoundOnAGenericParameterIsReported() throws {
        XCTAssertEqual(
            try violationsOfDomainDependsOnNothing(injecting: """
            public struct Broken {
                public func present<T: UserViewModel>(_ screen: T) {}
            }
            """),
            ["Broken -> UserViewModel (genericConstraint)"]
        )
    }

    func testASupertypeIsReported() throws {
        XCTAssertEqual(
            try violationsOfDomainDependsOnNothing(injecting: """
            public final class Broken: UserViewModel {}
            """),
            ["Broken -> UserViewModel (inheritance)"]
        )
    }

    /// A module is reached the moment a file imports it — provided the layer was told
    /// which modules are its own.
    func testAnImportOfAnotherLayersModuleIsReported() throws {
        XCTAssertEqual(
            try violationsOfDomainDependsOnNothing(injecting: """
            import Presentation

            public struct Broken {}
            """),
            ["Presentation -> Presentation (import)"]
        )
    }

    /// Extending a type is not reaching for it: the extended type is the declaration's own
    /// subject. The dependency is still recorded, so the first assertion proves the rule
    /// held because `.extension` is excluded and not because nothing was found.
    func testExtendingATypeFromAnotherLayerIsNotAViolation() throws {
        let project = try makeProject(injecting: "Domain/Broken.swift", """
        extension UserViewModel {
            public var isBroken: Bool { true }
        }
        """)
        defer { project.remove() }

        let extended = project.scope.declarations()
            .first { $0.filePath.hasSuffix("Domain/Broken.swift") }
        XCTAssertEqual(
            extended?.dependencies.filter { $0.name == "UserViewModel" }.map(\.kind),
            [.extension],
            "The fixture is meant to record an extension dependency on UserViewModel"
        )

        let layers = Layers()
        XCTAssertEqual(project.violations(of: layers.domain.dependsOnNothing(), layers.all), [])
    }

    // MARK: - What each rule means

    func testOnlyDependsOnAcceptsTheListedLayersAndRejectsTheRest() throws {
        let project = try makeProject(injecting: "Data/Reporting.swift", """
        public struct Reporting {
            private let logger: Logger
            private let user: User
            private let viewModel: UserViewModel
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.data.onlyDependsOn(layers.domain, layers.core), layers.all),
            ["Reporting -> UserViewModel (typeUsage)"]
        )
    }

    func testMustNotDependOnReportsOnlyTheForbiddenLayer() throws {
        let project = try makeProject(injecting: "Presentation/Dashboard.swift", """
        public struct Dashboard {
            private let repository: UserRepositoryImpl
            private let logger: Logger
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.presentation.mustNotDependOn(layers.data), layers.all),
            ["Dashboard -> UserRepositoryImpl (typeUsage)"]
        )
    }

    func testDependsOnNothingIgnoresTypesOfItsOwnLayerAndOfNoLayer() throws {
        let project = try makeProject(injecting: "Domain/Session.swift", """
        import Foundation

        public struct Session {
            private let user: User
            private let identifier: UUID
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(project.violations(of: layers.domain.dependsOnNothing(), layers.all), [])
    }

    /// `dependsOn` is the strictest rule of the four: it reports every dependency that is
    /// not in the target layer, *including* the source layer's own types. `UserView` is
    /// reported for using `UserViewModel`, its neighbour in Presentation. Read it as
    /// "depends on this layer and nothing else", not as "reaches this layer at least once".
    func testDependsOnReportsEveryDependencyOutsideTheTargetLayerIncludingItsOwn() throws {
        let project = try makeProject(injecting: "Presentation/Dashboard.swift", """
        public struct Dashboard {
            private let user: User
            private let logger: Logger
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.presentation.dependsOn(layers.domain), layers.all),
            [
                "Dashboard -> Logger (typeUsage)",
                // Twice: the stored property and the initialiser parameter.
                "UserView -> UserViewModel (typeUsage)",
                "UserView -> UserViewModel (typeUsage)",
            ]
        )
    }

    // MARK: - Passes that mean nothing

    /// A rule over a layer that matched no declaration passes, because there was nothing
    /// to contradict it. Only the *scope* is guarded against being empty, not the layer,
    /// so a mistyped directory name reads as a green run. Pinned here as the behaviour it
    /// is, rather than left for a reader to discover on a rule that never ran.
    func testARuleOverALayerThatMatchesNothingPassesVacuously() throws {
        let project = try makeProject()
        defer { project.remove() }

        let mistyped = Layer(name: "Domian", directory: "Domian")
        let layers = Layers()

        XCTAssertTrue(project.scope.declarations().allSatisfy { !mistyped.resideIn($0) })
        XCTAssertEqual(project.violations(of: mistyped.mustNotDependOn(layers.presentation), layers.all), [])
    }

    /// `dependsOn` reports dependencies that leave the target layer, so a layer that
    /// reaches for nothing satisfies it without ever depending on the target.
    func testDependsOnPassesForALayerThatDependsOnNothing() throws {
        let project = try makeProject(injecting: "Presentation/Isolated.swift", """
        public struct Isolated {}
        """)
        defer { project.remove() }

        let layers = Layers()
        let isolated = Layer(name: "Isolated", predicate: { $0.name == "Isolated" })

        XCTAssertEqual(project.violations(of: isolated.dependsOn(layers.domain), layers.all + [isolated]), [])
    }

    func testAnEmptyScopeIsReportedRatherThanPassed() throws {
        let root = NSTemporaryDirectory() + "LayerRuleTests_" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }

        let scope = try Conformant.scope(directory: root, policy: .lenient)
        let layers = Layers()
        let result = scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.domain.dependsOnNothing())
        }

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.violations, [], "An empty scope is a scope problem, not a violation")
        XCTAssertEqual(result.scopeProblems.count, 1)
        XCTAssertTrue(result.scopeProblems[0].contains("no Swift files"), result.description)
    }

    func testAScopeWithUnreadableCodeIsReportedRatherThanPassed() throws {
        let project = try makeProject(injecting: "Domain/Truncated.swift", """
        public struct Truncated {
            public func broken( -> {
        """, policy: .warning)
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.domain.dependsOnNothing())
        }

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.violations, [])
        XCTAssertEqual(result.scopeProblems.count, 1)
        XCTAssertTrue(result.scopeProblems[0].contains("failed to parse"), result.description)
    }

    // MARK: - What a failing run tells the reader

    func testAReportedViolationNamesTheRuleTheDeclarationAndItsLocation() throws {
        let project = try makeProject(injecting: "Domain/Broken.swift", """
        public struct Broken {
            private let viewModel: UserViewModel
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.domain.mustNotDependOn(layers.presentation))
        }

        XCTAssertEqual(result.violations.count, 1, result.description)
        let message = try XCTUnwrap(result.violations.first)
        XCTAssertTrue(message.contains("Layer 'Domain' must not depend on: Presentation"), message)
        XCTAssertTrue(message.contains("Depends on forbidden layer 'Presentation'"), message)
        XCTAssertTrue(message.contains("In: Broken"), message)
        XCTAssertTrue(message.contains("Domain/Broken.swift:1"), message)
    }

    func testTheSameProjectReportsTheSameViolationsInTheSameOrder() throws {
        let project = try makeProject(injecting: "Domain/Broken.swift", """
        public struct Broken {
            private let viewModel: UserViewModel
            private let repository: UserRepositoryImpl
        }
        """)
        defer { project.remove() }

        func run() -> [String] {
            let layers = Layers()
            return project.scope.checkArchitecture { rules in
                layers.all.forEach(rules.defineLayer)
                rules.add(layers.domain.dependsOnNothing())
            }.violations
        }

        XCTAssertEqual(run().count, 2)
        XCTAssertEqual(run(), run())
    }

    // MARK: - Which layer a declaration belongs to

    func testTheFirstDefinedLayerWinsWhenTwoLayersMatchTheSameDeclaration() throws {
        let project = try makeProject()
        defer { project.remove() }

        let byDirectory = Layer(name: "Presentation", directory: "Presentation")
        let byName = Layer(name: "ViewModels", predicate: { $0.name.hasSuffix("ViewModel") })

        let viewModel = try XCTUnwrap(project.scope.declarations().first { $0.name == "UserViewModel" })
        XCTAssertTrue(byDirectory.resideIn(viewModel))
        XCTAssertTrue(byName.resideIn(viewModel))

        XCTAssertEqual(layerContaining(viewModel, in: project, layers: [byDirectory, byName]), "Presentation")
        XCTAssertEqual(layerContaining(viewModel, in: project, layers: [byName, byDirectory]), "ViewModels")
    }

    /// A directory layer matches a path segment. `Data` is not `Metadata`, and a rule that
    /// took it for one would report violations against files nobody put in that layer.
    func testADirectoryLayerMatchesAPathSegmentAndNotASubstring() throws {
        let project = try makeProject(injecting: "Metadata/Tag.swift", """
        public struct Tag {}
        """)
        defer { project.remove() }

        XCTAssertEqual(project.declarations(in: Layer(name: "Data", directory: "Data")), ["UserRepositoryImpl"])
    }

    // MARK: - Fixture

    /// The layers of the fixture. Each knows its module name as well as its directory, so
    /// an `import Domain` resolves to the same layer that `struct User` lives in.
    private struct Layers {
        let core = Layer.directoryAndModule("Core")
        let domain = Layer.directoryAndModule("Domain")
        let data = Layer.directoryAndModule("Data")
        let presentation = Layer.directoryAndModule("Presentation")

        var all: [Layer] { [core, domain, data, presentation] }
    }

    private func layerContaining(_ declaration: any SwiftDeclaration, in project: LayeredProject, layers: [Layer]) -> String? {
        let context = ArchitectureRuleContext(
            scope: project.scope,
            declarations: project.scope.declarations(),
            layers: layers
        )
        return context.layerContaining(declaration: declaration)?.name
    }

    private func makeProject(
        injecting relativePath: String? = nil,
        _ contents: String = "",
        policy: ScopePolicy = .strict
    ) throws -> LayeredProject {
        var files = Self.cleanProject
        if let relativePath {
            files[relativePath] = contents
        }
        return try LayeredProject.write(files, named: "LayerRuleTests", policy: policy)
    }

    /// Every layer depends only downwards: Presentation and Data on Domain and Core,
    /// Domain and Core on nothing but the standard library.
    private static let cleanProject: [String: String] = [
        "Core/Logger.swift": """
        public struct Logger {
            public init() {}
            public func log(_ message: String) {}
        }
        """,
        "Core/Clock.swift": """
        public struct Clock {
            public static let shared = Clock()
            public init() {}
        }
        """,
        "Domain/User.swift": """
        public struct User {
            public let id: String
            public init(id: String) { self.id = id }
        }
        """,
        "Domain/UserRepository.swift": """
        public protocol UserRepository {
            func find(id: String) -> User?
        }
        """,
        "Domain/GetUser.swift": """
        public struct GetUser {
            private let repository: UserRepository
            public init(repository: UserRepository) { self.repository = repository }
            public func callAsFunction(id: String) -> User? { repository.find(id: id) }
        }
        """,
        "Data/UserRepositoryImpl.swift": """
        public final class UserRepositoryImpl: UserRepository {
            private let logger = Logger()
            public init() {}
            public func find(id: String) -> User? { nil }
        }
        """,
        "Presentation/UserViewModel.swift": """
        public final class UserViewModel {
            private let getUser: GetUser
            public init(getUser: GetUser) { self.getUser = getUser }
        }
        """,
        "Presentation/UserView.swift": """
        public struct UserView {
            private let viewModel: UserViewModel
            public init(viewModel: UserViewModel) { self.viewModel = viewModel }
        }
        """,
    ]

    /// The violations `Domain` reports when it should depend on nothing, with one file
    /// added to it. Every dependency-kind test above differs only in that file.
    private func violationsOfDomainDependsOnNothing(injecting contents: String) throws -> [String] {
        let project = try makeProject(injecting: "Domain/Broken.swift", contents)
        defer { project.remove() }

        let layers = Layers()
        return project.violations(of: layers.domain.dependsOnNothing(), layers.all)
    }
}
