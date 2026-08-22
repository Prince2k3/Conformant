//
//  CleanArchitectureTests.swift
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

/// Clean Architecture, whose whole content is one rule: source-level dependencies point
/// inward. Entities know nothing, use cases know entities, adapters know use cases,
/// frameworks know everything.
///
/// The rule is not "layers should be tidy" — it is what lets the inner rings be compiled,
/// tested, and reasoned about without a database or a UI in the room. Each outward arrow
/// below is a way that property is lost.
final class CleanArchitectureTests: XCTestCase {

    func testTheAppSatisfiesTheDependencyRule() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.entities.dependsOnNothing())
            rules.add(layers.useCases.onlyDependsOn(layers.entities))
            rules.add(layers.adapters.onlyDependsOn(layers.useCases, layers.entities))
            rules.add(layers.infrastructure.onlyDependsOn(layers.adapters, layers.useCases, layers.entities))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    /// Dependency inversion is what keeps the middle ring clean: the use case names the
    /// port it declared, and the adapter in the outer ring conforms to it. The arrow
    /// crosses the boundary in the legal direction, and this asserts it is really there
    /// rather than absent.
    func testTheAdapterPointsInwardByConformingToThePortTheUseCaseOwns() throws {
        let project = try makeApp()
        defer { project.remove() }

        let repository = try XCTUnwrap(project.scope.declarations().first { $0.name == "OrderRepository" })
        XCTAssertTrue(
            repository.dependencies.contains { $0.name == "OrderGateway" },
            "The adapter is meant to conform to the use-case layer's port"
        )

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.adapters.onlyDependsOn(layers.useCases, layers.entities), layers.all),
            []
        )
    }

    /// The inversion undone. Naming the concrete gateway instead of the port drags the
    /// database into the use case's test.
    func testAUseCaseThatNamesAConcreteGatewayIsReported() throws {
        let project = try makeApp(injecting: "UseCases/ArchiveOrder.swift", """
        public struct ArchiveOrder {
            private let repository: OrderRepository
            public init(repository: OrderRepository) { self.repository = repository }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.useCases.onlyDependsOn(layers.entities), layers.all),
            [
                "ArchiveOrder -> OrderRepository (typeUsage)",
                "ArchiveOrder -> OrderRepository (typeUsage)",
            ]
        )
    }

    /// The innermost ring reaching all the way out to a framework. This is the arrow the
    /// pattern is drawn to forbid, and the one that makes an entity impossible to
    /// construct in a test.
    func testAnEntityThatReachesForTheDatabaseIsReported() throws {
        let project = try makeApp(injecting: "Entities/Invoice.swift", """
        public struct Invoice {
            public init() {}
            public func persist() {
                _ = SQLiteOrderStore()
            }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.entities.dependsOnNothing(), layers.all),
            ["Invoice -> SQLiteOrderStore (instantiation)"]
        )
    }

    /// An adapter skipping its use case and talking to the framework directly. Nothing in
    /// the middle ring is wrong; the middle ring has simply stopped being on the path.
    func testAnAdapterThatSkipsTheUseCaseAndTalksToTheFrameworkIsReported() throws {
        let project = try makeApp(injecting: "Adapters/OrderController.swift", """
        public struct OrderController {
            private let store: SQLiteOrderStore
            public init(store: SQLiteOrderStore) { self.store = store }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.adapters.onlyDependsOn(layers.useCases, layers.entities), layers.all),
            [
                "OrderController -> SQLiteOrderStore (typeUsage)",
                "OrderController -> SQLiteOrderStore (typeUsage)",
            ]
        )
    }

    /// The outermost ring is allowed to know every ring inside it — that is where wiring
    /// lives. `AppAssembly` names one type from each, and none of it is a violation.
    func testTheOutermostRingMayNameEveryRingInsideIt() throws {
        let project = try makeApp()
        defer { project.remove() }

        let assembly = try XCTUnwrap(project.scope.declarations().first { $0.name == "AppAssembly" })
        let named = Set(assembly.dependencies.map(\.name))
        XCTAssertTrue(named.isSuperset(of: ["PlaceOrder", "OrderRepository", "OrderPresenter"]), "\(named)")

        let layers = Layers()
        XCTAssertEqual(
            project.violations(
                of: layers.infrastructure.onlyDependsOn(layers.adapters, layers.useCases, layers.entities),
                layers.all
            ),
            []
        )
    }

    // MARK: - The app

    private struct Layers {
        let entities = Layer.directoryAndModule("Entities")
        let useCases = Layer.directoryAndModule("UseCases")
        let adapters = Layer.directoryAndModule("Adapters")
        let infrastructure = Layer.directoryAndModule("Infrastructure")

        var all: [Layer] { [entities, useCases, adapters, infrastructure] }
    }

    private func makeApp(injecting relativePath: String? = nil, _ contents: String = "") throws -> LayeredProject {
        var files = Self.app
        if let relativePath { files[relativePath] = contents }
        return try LayeredProject.write(files, named: "Clean")
    }

    private static let app: [String: String] = [
        "Entities/Money.swift": """
        public struct Money {
            public let amount: Int
            public init(amount: Int) { self.amount = amount }
        }
        """,
        "Entities/Order.swift": """
        public struct Order {
            public let id: String
            public let total: Money
            public init(id: String, total: Money) {
                self.id = id
                self.total = total
            }
        }
        """,
        "UseCases/OrderGateway.swift": """
        public protocol OrderGateway {
            func save(_ order: Order)
        }
        """,
        "UseCases/PlaceOrder.swift": """
        public struct PlaceOrder {
            private let gateway: OrderGateway
            public init(gateway: OrderGateway) { self.gateway = gateway }
            public func callAsFunction(id: String, amount: Int) -> Order {
                let order = Order(id: id, total: Money(amount: amount))
                gateway.save(order)
                return order
            }
        }
        """,
        "Adapters/OrderPresenter.swift": """
        public struct OrderPresenter {
            public init() {}
            public func format(_ order: Order) -> String {
                "\\(order.id): \\(order.total.amount)"
            }
        }
        """,
        "Adapters/OrderRepository.swift": """
        public final class OrderRepository: OrderGateway {
            private var saved: [Order] = []
            public init() {}
            public func save(_ order: Order) { saved.append(order) }
        }
        """,
        "Infrastructure/SQLiteOrderStore.swift": """
        public final class SQLiteOrderStore {
            private let repository = OrderRepository()
            public init() {}
            public func write(_ order: Order) { repository.save(order) }
        }
        """,
        "Infrastructure/AppAssembly.swift": """
        public struct AppAssembly {
            public init() {}
            public func placeOrder() -> PlaceOrder {
                PlaceOrder(gateway: OrderRepository())
            }
            public func presenter() -> OrderPresenter {
                OrderPresenter()
            }
        }
        """,
    ]
}
