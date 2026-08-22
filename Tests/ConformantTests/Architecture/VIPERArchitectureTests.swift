//
//  VIPERArchitectureTests.swift
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

/// VIPER, which is five roles and a fixed set of arrows between them: the view talks to
/// the presenter, the presenter to the interactor and the router, and the interactor to
/// entities alone.
///
/// The pattern's cost is the ceremony; its return is that the interactor holds the logic
/// and knows nothing about a screen. An interactor that names a view has paid the cost
/// without collecting the return, and nothing but a rule like these will say so.
final class VIPERArchitectureTests: XCTestCase {

    func testTheModuleSatisfiesTheRulesOfVIPER() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.entity.dependsOnNothing())
            rules.add(layers.interactor.onlyDependsOn(layers.entity))
            rules.add(layers.presenter.onlyDependsOn(layers.interactor, layers.router, layers.entity))
            rules.add(layers.view.onlyDependsOn(layers.presenter, layers.entity))
            rules.add(layers.router.onlyDependsOn(layers.view, layers.presenter, layers.interactor))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    /// The interactor is the half of the module that is worth testing, and it is worth
    /// testing precisely because no view is reachable from it.
    func testAnInteractorThatNamesAViewIsReported() throws {
        let project = try makeApp(injecting: "Interactor/AvatarInteractor.swift", """
        public final class AvatarInteractor {
            private var view: ProfileView?
            public init() {}
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.interactor.onlyDependsOn(layers.entity), layers.all),
            ["AvatarInteractor -> ProfileView (typeUsage)"]
        )
    }

    /// The view short-circuiting the presenter. The screen now fetches its own data, which
    /// is the arrangement VIPER was adopted to leave behind.
    func testAViewThatCallsTheInteractorDirectlyIsReported() throws {
        let project = try makeApp(injecting: "View/AvatarView.swift", """
        public struct AvatarView {
            private let interactor: ProfileInteractor
            public init(interactor: ProfileInteractor) { self.interactor = interactor }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.view.onlyDependsOn(layers.presenter, layers.entity), layers.all),
            [
                "AvatarView -> ProfileInteractor (typeUsage)",
                "AvatarView -> ProfileInteractor (typeUsage)",
            ]
        )
    }

    /// Building screens is the router's job. A presenter that constructs a view has taken
    /// it back, and the module can no longer be presented from anywhere else.
    func testAPresenterThatBuildsAViewIsReported() throws {
        let project = try makeApp(injecting: "Presenter/SettingsPresenter.swift", """
        public final class SettingsPresenter {
            public init() {}
            public func present(presenter: ProfilePresenter) -> ProfileView {
                ProfileView(presenter: presenter)
            }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(
                of: layers.presenter.onlyDependsOn(layers.interactor, layers.router, layers.entity),
                layers.all
            ),
            [
                "SettingsPresenter -> ProfileView (typeUsage)",
                "SettingsPresenter -> ProfileView (instantiation)",
            ]
        )
    }

    /// The router is the one role allowed to know the others: assembling the module is
    /// what it is for. Stated as its own test so the permission is deliberate rather than
    /// an omission.
    func testTheRouterMayAssembleTheModuleFromEveryOtherRole() throws {
        let project = try makeApp()
        defer { project.remove() }

        let router = try XCTUnwrap(project.scope.declarations().first { $0.name == "ProfileRouter" })
        let named = Set(router.dependencies.map(\.name))
        XCTAssertTrue(named.isSuperset(of: ["ProfileView", "ProfilePresenter", "ProfileInteractor"]), "\(named)")

        let layers = Layers()
        XCTAssertEqual(
            project.violations(
                of: layers.router.onlyDependsOn(layers.view, layers.presenter, layers.interactor),
                layers.all
            ),
            []
        )
    }

    // MARK: - The module

    private struct Layers {
        let view = Layer.directoryAndModule("View")
        let interactor = Layer.directoryAndModule("Interactor")
        let presenter = Layer.directoryAndModule("Presenter")
        let entity = Layer.directoryAndModule("Entity")
        let router = Layer.directoryAndModule("Router")

        var all: [Layer] { [view, interactor, presenter, entity, router] }
    }

    private func makeApp(injecting relativePath: String? = nil, _ contents: String = "") throws -> LayeredProject {
        var files = Self.app
        if let relativePath { files[relativePath] = contents }
        return try LayeredProject.write(files, named: "VIPER")
    }

    private static let app: [String: String] = [
        "Entity/Profile.swift": """
        public struct Profile {
            public let name: String
            public let email: String
            public init(name: String, email: String) {
                self.name = name
                self.email = email
            }
        }
        """,
        "Interactor/ProfileInteractor.swift": """
        public final class ProfileInteractor {
            public init() {}
            public func load() -> Profile {
                Profile(name: "Ada", email: "ada@example.com")
            }
        }
        """,
        "Router/ProfileRouter.swift": """
        public final class ProfileRouter {
            public init() {}
            public func makeProfile() -> ProfileView {
                ProfileView(presenter: ProfilePresenter(interactor: ProfileInteractor(), router: self))
            }
            public func routeToSettings() {}
        }
        """,
        "Presenter/ProfilePresenter.swift": """
        public final class ProfilePresenter {
            private let interactor: ProfileInteractor
            private let router: ProfileRouter
            public init(interactor: ProfileInteractor, router: ProfileRouter) {
                self.interactor = interactor
                self.router = router
            }
            public func title() -> String { interactor.load().name }
            public func didTapSettings() { router.routeToSettings() }
        }
        """,
        "View/ProfileView.swift": """
        public struct ProfileView {
            private let presenter: ProfilePresenter
            public init(presenter: ProfilePresenter) { self.presenter = presenter }
            public func title() -> String { presenter.title() }
        }
        """,
    ]
}
