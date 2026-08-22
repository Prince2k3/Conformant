//
//  HexagonalArchitectureTests.swift
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

/// Hexagonal architecture — ports and adapters. The application sits inside the hexagon
/// and names only its ports; everything that talks to the world outside is an adapter
/// plugged into one of them.
///
/// The layout is deliberately the one that looks tidy but is not enforced by the compiler:
/// an adapter is a plain type, so nothing stops the domain from constructing one, and
/// nothing stops a driving adapter from calling a driven one directly and leaving the
/// hexagon out of its own use case.
final class HexagonalArchitectureTests: XCTestCase {

    func testTheApplicationSatisfiesPortsAndAdapters() throws {
        let project = try makeApp()
        defer { project.remove() }

        let layers = Layers()
        let result = project.scope.checkArchitecture { rules in
            layers.all.forEach(rules.defineLayer)
            rules.add(layers.domain.onlyDependsOn(layers.ports))
            rules.add(layers.ports.onlyDependsOn(layers.domain))
            rules.add(layers.inbound.onlyDependsOn(layers.ports, layers.domain))
            rules.add(layers.outbound.onlyDependsOn(layers.ports, layers.domain))
            rules.add(layers.domain.mustNotDependOn(layers.inbound, layers.outbound))
        }

        XCTAssertEqual(result.messages, [], result.description)
        project.assertEveryLayerIsPopulated(layers.all)
    }

    /// The inside of the hexagon reaching for a driven adapter. The service still works —
    /// against Postgres, and only against Postgres.
    func testTheDomainReachingForADrivenAdapterIsReported() throws {
        let project = try makeApp(injecting: "Domain/AuditLog.swift", """
        public struct AuditLog {
            public init() {}
            public func record(_ reservation: Reservation) {
                let store = PostgresReservationStore()
                store.save(reservation)
            }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.domain.mustNotDependOn(layers.inbound, layers.outbound), layers.all),
            ["AuditLog -> PostgresReservationStore (instantiation)"]
        )
    }

    /// One adapter calling another. The hexagon is still there; this request simply does
    /// not go through it, so no policy in the domain applies to it.
    func testADrivingAdapterThatCallsADrivenAdapterDirectlyIsReported() throws {
        let project = try makeApp(injecting: "Adapters/Inbound/AdminBookingHandler.swift", """
        public struct AdminBookingHandler {
            private let store: PostgresReservationStore
            public init(store: PostgresReservationStore) { self.store = store }
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.inbound.onlyDependsOn(layers.ports, layers.domain), layers.all),
            [
                "AdminBookingHandler -> PostgresReservationStore (typeUsage)",
                "AdminBookingHandler -> PostgresReservationStore (typeUsage)",
            ]
        )
    }

    /// A port written against one particular adapter. A port that names its implementation
    /// is no longer a port — the second adapter cannot be written.
    func testAPortThatNamesAnAdapterIsReported() throws {
        let project = try makeApp(injecting: "Ports/Notifier.swift", """
        public protocol Notifier {
            func notify(handler: HTTPBookingHandler)
        }
        """)
        defer { project.remove() }

        let layers = Layers()
        XCTAssertEqual(
            project.violations(of: layers.ports.onlyDependsOn(layers.domain), layers.all),
            ["Notifier -> HTTPBookingHandler (typeUsage)"]
        )
    }

    /// Both adapters are plugged into ports rather than into the service. Asserted
    /// directly, because it is what makes the passes above mean "the hexagon is closed"
    /// rather than "the adapters happen to depend on nothing".
    func testEachAdapterIsPluggedIntoAPortRatherThanIntoTheService() throws {
        let project = try makeApp()
        defer { project.remove() }

        let inbound = try XCTUnwrap(project.scope.declarations().first { $0.name == "HTTPBookingHandler" })
        XCTAssertTrue(inbound.dependencies.contains { $0.name == "BookRoom" })
        XCTAssertFalse(inbound.dependencies.contains { $0.name == "BookingService" })

        let outbound = try XCTUnwrap(project.scope.declarations().first { $0.name == "PostgresReservationStore" })
        XCTAssertTrue(outbound.dependencies.contains { $0.name == "ReservationStore" })
    }

    // MARK: - The application

    private struct Layers {
        let domain = Layer.directoryAndModule("Domain")
        let ports = Layer.directoryAndModule("Ports")
        let inbound = Layer.directoryAndModule("Inbound", directory: "Adapters/Inbound")
        let outbound = Layer.directoryAndModule("Outbound", directory: "Adapters/Outbound")

        var all: [Layer] { [domain, ports, inbound, outbound] }
    }

    private func makeApp(injecting relativePath: String? = nil, _ contents: String = "") throws -> LayeredProject {
        var files = Self.app
        if let relativePath { files[relativePath] = contents }
        return try LayeredProject.write(files, named: "Hexagonal")
    }

    private static let app: [String: String] = [
        "Domain/Reservation.swift": """
        public struct Reservation {
            public let room: String
            public let nights: Int
            public init(room: String, nights: Int) {
                self.room = room
                self.nights = nights
            }
        }
        """,
        "Domain/BookingPolicy.swift": """
        public struct BookingPolicy {
            public init() {}
            public func allows(_ reservation: Reservation) -> Bool {
                reservation.nights > 0
            }
        }
        """,
        "Ports/BookRoom.swift": """
        public protocol BookRoom {
            func book(room: String, nights: Int) -> Reservation?
        }
        """,
        "Ports/ReservationStore.swift": """
        public protocol ReservationStore {
            func save(_ reservation: Reservation)
        }
        """,
        "Domain/BookingService.swift": """
        public struct BookingService: BookRoom {
            private let store: ReservationStore
            private let policy = BookingPolicy()
            public init(store: ReservationStore) { self.store = store }
            public func book(room: String, nights: Int) -> Reservation? {
                let reservation = Reservation(room: room, nights: nights)
                guard policy.allows(reservation) else { return nil }
                store.save(reservation)
                return reservation
            }
        }
        """,
        "Adapters/Inbound/HTTPBookingHandler.swift": """
        public struct HTTPBookingHandler {
            private let bookRoom: BookRoom
            public init(bookRoom: BookRoom) { self.bookRoom = bookRoom }
            public func handle(room: String, nights: Int) -> Reservation? {
                bookRoom.book(room: room, nights: nights)
            }
        }
        """,
        "Adapters/Outbound/PostgresReservationStore.swift": """
        public final class PostgresReservationStore: ReservationStore {
            private var rows: [Reservation] = []
            public init() {}
            public func save(_ reservation: Reservation) { rows.append(reservation) }
        }
        """,
    ]
}
