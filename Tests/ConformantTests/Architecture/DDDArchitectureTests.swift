//
//  DDDArchitectureTests.swift
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

/// Domain-Driven Design, in both of its dimensions: the tactical layering inside a
/// context — domain, application, infrastructure — and the strategic boundary between
/// two bounded contexts.
///
/// `Order` and `Consignment` are different models of overlapping facts, and they are
/// meant to stay different. What keeps them apart is not the directory layout but the
/// anti-corruption layer: one type, allowed to name both vocabularies, whose job is to
/// translate. Every other declaration that names the other context's model has quietly
/// merged the two models, and the rules below are what notices.
final class DDDArchitectureTests: XCTestCase {

    func testBothContextsSatisfyTheirLayeringAndTheirBoundary() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)

            // Tactical: the domain is the bottom of each context.
            rules.add(layers.orderingDomain.dependsOnNothing())
            rules.add(layers.orderingApplication.onlyDependsOn(layers.orderingDomain))
            rules.add(layers.orderingInfrastructure.onlyDependsOn(layers.orderingDomain))
            rules.add(layers.shippingDomain.dependsOnNothing())
            rules.add(layers.shippingApplication.onlyDependsOn(layers.shippingDomain))

            // Strategic: only the anti-corruption layer speaks both vocabularies.
            rules.add(layers.orderingApplication.mustNotDependOn(layers.shippingDomain, layers.shippingApplication))
            rules.add(layers.orderingInfrastructure.mustNotDependOn(layers.shippingDomain, layers.shippingApplication))
            rules.add(layers.antiCorruption.onlyDependsOn(layers.orderingDomain, layers.shippingDomain))
            rules.add(layers.shippingDomain.mustNotDependOn(layers.orderingDomain, layers.orderingApplication))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    /// The anti-corruption layer is the exception the boundary is stated around: it names
    /// `Order` and `Consignment` in the same file, on purpose, and that is not a
    /// violation.
    func testTheAntiCorruptionLayerMayNameBothVocabularies() throws {
        let project = try makeApp()
        defer { project.remove() }

        let adapter = try XCTUnwrap(project.scope.declarations().first { $0.name == "ShippingBookingAdapter" })
        let named = Set(adapter.dependencies.map(\.name))
        XCTAssertTrue(named.isSuperset(of: ["Order", "Consignment"]), "\(named)")

        let layers = Layers()
        XCTAssertEqual(
            project.violations(
                of: layers.antiCorruption.onlyDependsOn(layers.orderingDomain, layers.shippingDomain),
                layers.all
            ),
            []
        )
    }

    /// And it is the *only* exception. Stated over the whole scope rather than over one
    /// layer, because the thing worth knowing is not that some particular file behaved,
    /// but that the translation happens in exactly one place.
    func testTranslationHappensInExactlyOnePlace() throws {
        let project = try makeApp()
        defer { project.remove() }

        let shippingVocabulary: Set<String> = ["Consignment", "ShippingService"]
        let speakers = project.scope.declarations()
            .filter { !$0.filePath.contains("/Shipping/") }
            .filter { !$0.dependencies.filter { shippingVocabulary.contains($0.name) }.isEmpty }
            .map(\.name)
            .sorted()

        XCTAssertEqual(speakers, ["ShippingBookingAdapter"])
    }

    /// The tactical rule. A domain type that knows how it is stored cannot be reasoned
    /// about, or tested, without the store.
    func testADomainTypeThatKnowsItsPersistenceIsReported() throws {
        let project = try makeApp(injecting: "Ordering/Domain/Customer.swift", """
        public struct Customer {
            private let repository: InMemoryOrderRepository
            public init(repository: InMemoryOrderRepository) { self.repository = repository }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.orderingDomain.dependsOnNothing(), layers.all),
            [
                "Customer -> InMemoryOrderRepository (typeUsage)",
                "Customer -> InMemoryOrderRepository (typeUsage)",
            ]
        )
    }

    /// The strategic rule, broken the way it is usually broken: not by a redesign, but by
    /// one use case that needed a shipping field and took the shipping type. From then on
    /// the two contexts share a model, and neither can change alone.
    func testAUseCaseThatTakesTheOtherContextsModelIsReported() throws {
        let project = try makeApp(injecting: "Ordering/Application/QuoteShipping.swift", """
        public struct QuoteShipping {
            public init() {}
            public func quote(for consignment: Consignment) -> Int {
                consignment.weight * 2
            }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(
                of: layers.orderingApplication.mustNotDependOn(layers.shippingDomain, layers.shippingApplication),
                layers.all
            ),
            ["QuoteShipping -> Consignment (typeUsage)"]
        )
    }

    /// The boundary is not symmetrical by accident — it has to be asserted from both
    /// sides. Shipping reaching back into Ordering is the same merge in the other
    /// direction, and the anti-corruption layer does not excuse it.
    func testTheOtherContextReachingBackIsReported() throws {
        let project = try makeApp(injecting: "Shipping/Domain/OrderSummary.swift", """
        public struct OrderSummary {
            private let order: Order
            public init(order: Order) { self.order = order }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(
                of: layers.shippingDomain.mustNotDependOn(layers.orderingDomain, layers.orderingApplication),
                layers.all
            ),
            [
                "OrderSummary -> Order (typeUsage)",
                "OrderSummary -> Order (typeUsage)",
            ]
        )
    }

    // MARK: - The two contexts

    private struct Layers {
        let orderingDomain = Layer.directoryAndModule("OrderingDomain", directory: "Ordering/Domain")
        let orderingApplication = Layer.directoryAndModule("OrderingApplication", directory: "Ordering/Application")
        let orderingInfrastructure = Layer.directoryAndModule("OrderingInfrastructure", directory: "Ordering/Infrastructure")
        let antiCorruption = Layer.directoryAndModule("AntiCorruption", directory: "Ordering/AntiCorruption")
        let shippingDomain = Layer.directoryAndModule("ShippingDomain", directory: "Shipping/Domain")
        let shippingApplication = Layer.directoryAndModule("ShippingApplication", directory: "Shipping/Application")

        var all: [Layer] {
            [
                orderingDomain, orderingApplication, orderingInfrastructure,
                antiCorruption, shippingDomain, shippingApplication,
            ]
        }
    }

    private func makeApp(injecting relativePath: String? = nil, _ contents: String = "") throws -> LayeredProject {
        var files = Self.app
        if let relativePath { files[relativePath] = contents }
        return try LayeredProject.write(files, named: "DDD")
    }

    private static let app: [String: String] = [
        "Ordering/Domain/OrderId.swift": """
        public struct OrderId {
            public let value: String
            public init(value: String) { self.value = value }
        }
        """,
        "Ordering/Domain/Order.swift": """
        public struct Order {
            public let id: OrderId
            public let lines: [String]
            public init(id: OrderId, lines: [String]) {
                self.id = id
                self.lines = lines
            }
        }
        """,
        "Ordering/Domain/OrderRepository.swift": """
        public protocol OrderRepository {
            func store(_ order: Order)
        }
        """,
        "Ordering/Domain/ShipmentBooking.swift": """
        /// The port the Ordering context states in its own vocabulary. Shipping does not
        /// appear in it — that is the point.
        public protocol ShipmentBooking {
            func book(_ order: Order) -> String
        }
        """,
        "Ordering/Application/PlaceOrder.swift": """
        public struct PlaceOrder {
            private let repository: OrderRepository
            private let booking: ShipmentBooking
            public init(repository: OrderRepository, booking: ShipmentBooking) {
                self.repository = repository
                self.booking = booking
            }
            public func callAsFunction(_ order: Order) -> String {
                repository.store(order)
                return booking.book(order)
            }
        }
        """,
        "Ordering/Infrastructure/InMemoryOrderRepository.swift": """
        public final class InMemoryOrderRepository: OrderRepository {
            private var orders: [Order] = []
            public init() {}
            public func store(_ order: Order) { orders.append(order) }
        }
        """,
        "Ordering/AntiCorruption/ShippingBookingAdapter.swift": """
        /// The translation, and the only declaration outside Shipping allowed to name a
        /// Shipping type.
        public struct ShippingBookingAdapter: ShipmentBooking {
            private let service = ShippingService()
            public init() {}
            public func book(_ order: Order) -> String {
                service.dispatch(Consignment(reference: order.id.value, weight: order.lines.count))
            }
        }
        """,
        "Shipping/Domain/Consignment.swift": """
        public struct Consignment {
            public let reference: String
            public let weight: Int
            public init(reference: String, weight: Int) {
                self.reference = reference
                self.weight = weight
            }
        }
        """,
        "Shipping/Domain/ShippingService.swift": """
        public struct ShippingService {
            public init() {}
            public func dispatch(_ consignment: Consignment) -> String {
                consignment.reference
            }
        }
        """,
        "Shipping/Application/DispatchConsignment.swift": """
        public struct DispatchConsignment {
            private let service: ShippingService
            public init(service: ShippingService) { self.service = service }
            public func callAsFunction(_ consignment: Consignment) -> String {
                service.dispatch(consignment)
            }
        }
        """,
    ]
}
