//
//  MVVMArchitectureTests.swift
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

/// Model–View–ViewModel, stated as the two rules that make it worth adopting: the view
/// model never names a view, and the view never reaches past the view model.
///
/// The first rule is what makes a view model testable without a UI; the second is what
/// keeps the view free of decisions. Both are broken by a single line, and neither breaks
/// the build.
final class MVVMArchitectureTests: XCTestCase {

    func testTheAppSatisfiesTheRulesOfMVVM() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.model.dependsOnNothing())
            rules.add(layers.viewModel.mustNotDependOn(layers.view))
            rules.add(layers.view.onlyDependsOn(layers.viewModel))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    /// The rule the pattern exists for. A view model that names a view can only be
    /// exercised by building one, which is to say, not in a unit test.
    func testAViewModelThatNamesAViewIsReported() throws {
        let project = try makeApp(injecting: "ViewModel/TaskDetailViewModel.swift", """
        public final class TaskDetailViewModel {
            private var row: TaskRow?
            public init() {}
            public func show(title: String) {
                row = TaskRow(title: title)
            }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.viewModel.mustNotDependOn(layers.view), layers.all),
            [
                "TaskDetailViewModel -> TaskRow (typeUsage)",
                "TaskDetailViewModel -> TaskRow (instantiation)",
            ]
        )
    }

    /// The view reaching past its view model into the model. The screen still renders; the
    /// state it renders is now owned in two places.
    func testAViewThatReachesPastItsViewModelIntoTheModelIsReported() throws {
        let project = try makeApp(injecting: "View/TaskCountBadge.swift", """
        public struct TaskCountBadge {
            private let repository: TaskRepository
            public init(repository: TaskRepository) { self.repository = repository }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.view.onlyDependsOn(layers.viewModel), layers.all),
            [
                "TaskCountBadge -> TaskRepository (typeUsage)",
                "TaskCountBadge -> TaskRepository (typeUsage)",
            ]
        )
    }

    /// The model is the bottom of the stack: it knows neither of the layers above it. Here
    /// the reach is an `import`, so nothing in the file names a view at all, which is
    /// exactly the case a rule stated only over type names would miss. The violation is
    /// reported against the import itself, hence the module name on both sides.
    func testAModelThatImportsTheViewModuleIsReported() throws {
        let project = try makeApp(injecting: "Model/TaskExport.swift", """
        import View

        public struct TaskExport {
            public init() {}
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.model.dependsOnNothing(), layers.all),
            ["View -> View (import)"]
        )
    }

    /// A view model depending on the model is the arrow the pattern is built on, and a
    /// view depending on its view model likewise. Asserted so that the passes above are
    /// known to come from rules that had something to look at.
    func testTheArrowsThePatternIsBuiltOnAreNotViolations() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let viewModel = try XCTUnwrap(project.scope.declarations().first { $0.name == "TaskListViewModel" })
        XCTAssertTrue(viewModel.dependencies.contains { $0.name == "TaskRepository" })

        let screen = try XCTUnwrap(project.scope.declarations().first { $0.name == "TaskListScreen" })
        XCTAssertTrue(screen.dependencies.contains { $0.name == "TaskListViewModel" })

        XCTAssertEqual(project.violations(of: layers.viewModel.mustNotDependOn(layers.view), layers.all), [])
        XCTAssertEqual(project.violations(of: layers.view.onlyDependsOn(layers.viewModel), layers.all), [])
    }

    // MARK: - The app

    private struct Layers {
        let model = Layer.directoryAndModule("Model")
        let viewModel = Layer.directoryAndModule("ViewModel")
        let view = Layer.directoryAndModule("View")

        var all: [Layer] { [model, viewModel, view] }
    }

    private func makeApp(injecting relativePath: String? = nil, _ contents: String = "") throws -> LayeredProject {
        var files = Self.app
        if let relativePath { files[relativePath] = contents }
        return try LayeredProject.write(files, named: "MVVM")
    }

    private static let app: [String: String] = [
        "Model/Task.swift": """
        public struct Task {
            public let id: String
            public let title: String
            public let isDone: Bool
            public init(id: String, title: String, isDone: Bool) {
                self.id = id
                self.title = title
                self.isDone = isDone
            }
        }
        """,
        "Model/TaskRepository.swift": """
        public protocol TaskRepository {
            func outstanding() -> [Task]
        }
        """,
        "ViewModel/TaskListViewModel.swift": """
        public final class TaskListViewModel {
            private let repository: TaskRepository
            public private(set) var rows: [String] = []
            public init(repository: TaskRepository) { self.repository = repository }
            public func load() {
                rows = repository.outstanding().map(\\.title)
            }
        }
        """,
        "View/TaskRow.swift": """
        public struct TaskRow {
            public let title: String
            public init(title: String) { self.title = title }
        }
        """,
        "View/TaskListScreen.swift": """
        public struct TaskListScreen {
            private let viewModel: TaskListViewModel
            public init(viewModel: TaskListViewModel) { self.viewModel = viewModel }
            public func rows() -> [TaskRow] {
                viewModel.rows.map { TaskRow(title: $0) }
            }
        }
        """,
    ]
}
