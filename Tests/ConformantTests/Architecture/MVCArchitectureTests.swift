//
//  MVCArchitectureTests.swift
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

/// Model–View–Controller, in its original strict form: the controller is the only part
/// that knows both sides.
///
/// The rules are the ones the pattern is usually broken against. A view that reads the
/// model, or a model that calls back into a controller, still compiles and still runs —
/// which is why the loss is invisible until the model is reused somewhere without a UI.
final class MVCArchitectureTests: XCTestCase {

    func testTheAppSatisfiesTheRulesOfMVC() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.models.mustNotDependOn(layers.views, layers.controllers))
            rules.add(layers.views.mustNotDependOn(layers.models, layers.controllers))
            rules.add(layers.controllers.onlyDependsOn(layers.models, layers.views))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    /// The most common way MVC decays: a view that formats the model itself. It reads
    /// harmlessly — one property — and it is the reason the view can no longer be
    /// rendered from a preview, a test, or a second data source.
    func testAViewThatReadsTheModelIsReported() throws {
        let project = try makeApp(injecting: "Views/ArticleSummaryView.swift", """
        public struct ArticleSummaryView {
            private let article: Article
            public init(article: Article) { self.article = article }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.views.mustNotDependOn(layers.models, layers.controllers), layers.all),
            [
                "ArticleSummaryView -> Article (typeUsage)",
                "ArticleSummaryView -> Article (typeUsage)",
            ]
        )
    }

    /// A view that pushes the next screen itself. The arrow now points from the view to
    /// the controller, so the view can only be used by that one controller.
    func testAViewThatDrivesNavigationIsReported() throws {
        let project = try makeApp(injecting: "Views/ArticleListFooter.swift", """
        public struct ArticleListFooter {
            public init() {}
            public func showAll() {
                let controller = ArticleListController()
                controller.reload()
            }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.views.mustNotDependOn(layers.models, layers.controllers), layers.all),
            ["ArticleListFooter -> ArticleListController (instantiation)"]
        )
    }

    /// The model calling upwards. Cheap to write, and it makes the model unusable in any
    /// context that has no controller — a background sync, a command-line importer.
    func testAModelThatCallsBackIntoAControllerIsReported() throws {
        let project = try makeApp(injecting: "Models/Draft.swift", """
        public struct Draft {
            private weak var controller: ArticleListController?
            public init() {}
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.models.mustNotDependOn(layers.views, layers.controllers), layers.all),
            ["Draft -> ArticleListController (typeUsage)"]
        )
    }

    /// Models talking to models, and views composed of views, are not violations: the
    /// rules are about the three roles, not about every arrow in the app.
    func testDependenciesWithinARoleAreNotViolations() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let store = try XCTUnwrap(project.scope.declarations().first { $0.name == "ArticleStore" })
        XCTAssertTrue(store.dependencies.contains { $0.name == "Article" })

        XCTAssertEqual(
            project.violations(of: layers.models.mustNotDependOn(layers.views, layers.controllers), layers.all),
            []
        )
    }

    // MARK: - The app

    private struct Layers {
        let models = Layer.directoryAndModule("Models")
        let views = Layer.directoryAndModule("Views")
        let controllers = Layer.directoryAndModule("Controllers")

        var all: [Layer] { [models, views, controllers] }
    }

    private func makeApp(injecting relativePath: String? = nil, _ contents: String = "") throws -> LayeredProject {
        var files = Self.app
        if let relativePath { files[relativePath] = contents }
        return try LayeredProject.write(files, named: "MVC")
    }

    private static let app: [String: String] = [
        "Models/Article.swift": """
        public struct Article {
            public let id: String
            public let title: String
            public init(id: String, title: String) {
                self.id = id
                self.title = title
            }
        }
        """,
        "Models/ArticleStore.swift": """
        public final class ArticleStore {
            private var articles: [Article] = []
            public init() {}
            public func all() -> [Article] { articles }
        }
        """,
        "Views/ArticleCell.swift": """
        public struct ArticleCell {
            public let title: String
            public let subtitle: String
            public init(title: String, subtitle: String) {
                self.title = title
                self.subtitle = subtitle
            }
        }
        """,
        "Views/ArticleListView.swift": """
        public struct ArticleListView {
            public var cells: [ArticleCell]
            public var onSelect: (Int) -> Void
            public init(cells: [ArticleCell], onSelect: @escaping (Int) -> Void) {
                self.cells = cells
                self.onSelect = onSelect
            }
        }
        """,
        "Controllers/ArticleListController.swift": """
        public final class ArticleListController {
            private let store = ArticleStore()
            private var view: ArticleListView?
            public init() {}
            public func reload() {
                let cells = store.all().map { ArticleCell(title: $0.title, subtitle: $0.id) }
                view = ArticleListView(cells: cells, onSelect: { _ in })
            }
        }
        """,
    ]
}
