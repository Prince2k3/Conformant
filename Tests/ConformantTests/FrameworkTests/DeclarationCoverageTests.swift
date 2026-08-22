//
//  DeclarationCoverageTests.swift
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

/// Pins the guarantee that no Swift declaration form is silently invisible.
///
/// The corpus snapshots record *what* the extractor produces; these tests state *why*
/// each behavior matters, so a regression fails with a sentence rather than a diff.
final class DeclarationCoverageTests: XCTestCase {

    private let parser = SwiftSyntaxParser()

    private func parse(_ source: String) -> SwiftFile {
        parser.parse(source: source, path: "/coverage/Test.swift")
    }

    // MARK: - Nested types

    func testNestedTypesAreCollectedInTheirOwnRight() {
        let file = parse("""
        struct Outer {
            struct Inner {
                let repository: UserRepository
            }
            enum Kind { case primary }
            final class Deep {
                struct Deeper { let client: NetworkClient }
            }
        }
        """)

        XCTAssertEqual(file.structs.map(\.name), ["Outer", "Outer.Inner", "Outer.Deep.Deeper"])
        XCTAssertEqual(file.classes.map(\.name), ["Outer.Deep"])
        XCTAssertEqual(file.enums.map(\.name), ["Outer.Kind"])
    }

    func testNestedTypeDependenciesDoNotLeakToTheEnclosingType() {
        let file = parse("""
        struct Outer {
            struct Inner { let repository: UserRepository }
        }
        """)

        let outer = file.structs.first { $0.name == "Outer" }
        let inner = file.structs.first { $0.name == "Outer.Inner" }

        // A rule saying "Outer must not depend on UserRepository" was previously
        // unsatisfiable: the member belonged to Inner but was reported against Outer.
        XCTAssertEqual(outer?.dependencies.count, 0)
        XCTAssertTrue(inner?.dependencies.containsDependency(name: "UserRepository") ?? false)
        XCTAssertEqual(outer?.properties.count, 0)
        XCTAssertEqual(inner?.properties.map(\.name), ["repository"])
    }

    func testNestedDeclarationsKnowTheirParent() {
        let file = parse("""
        struct Outer {
            struct Inner { let value: Int }
        }
        """)

        let inner = file.structs.first { $0.name == "Outer.Inner" }
        XCTAssertEqual(inner?.parentName, "Outer")
        XCTAssertEqual(inner?.simpleName, "Inner")
        XCTAssertTrue(inner?.isNested ?? false)

        let outer = file.structs.first { $0.name == "Outer" }
        XCTAssertNil(outer?.parentName)
        XCTAssertEqual(outer?.simpleName, "Outer")
        XCTAssertFalse(outer?.isNested ?? true)

        XCTAssertEqual(inner?.properties.first?.parentName, "Outer.Inner")
    }

    // MARK: - Previously invisible declaration forms

    func testActorsAreExtracted() {
        let file = parse("""
        public actor BankAccount: Auditable {
            private var balance: Decimal = 0
            public func deposit(_ amount: Decimal) async throws {}
            deinit {}
        }
        @globalActor actor Background {}
        distributed actor Worker {}
        """)

        XCTAssertEqual(file.actors.map(\.name), ["BankAccount", "Background", "Worker"])

        let account = file.actors[0]
        // An actor has no superclass, so every inherited type is a conformance.
        XCTAssertEqual(account.protocols, ["Auditable"])
        XCTAssertTrue(account.implements(protocol: "Auditable"))
        XCTAssertTrue(account.hasProperty(named: "balance"))
        XCTAssertTrue(account.hasMethod(named: "deposit"))
        XCTAssertEqual(account.deinitializers.count, 1)

        XCTAssertTrue(file.actors[1].isGlobalActor)
        XCTAssertTrue(file.actors[2].isDistributed)
    }

    func testTypealiasesAreExtracted() {
        let file = parse("""
        public typealias Handler = (Request) -> Response
        typealias Pair<Value> = (Value, Value)
        """)

        XCTAssertEqual(file.typealiases.map(\.name), ["Handler", "Pair"])

        let handler = file.typealiases[0]
        XCTAssertEqual(handler.aliasedType, "(Request) -> Response")
        XCTAssertFalse(handler.isGeneric)
        XCTAssertTrue(handler.dependencies.containsDependency(name: "Request"))

        let pair = file.typealiases[1]
        XCTAssertEqual(pair.genericParameters, ["Value"])
        XCTAssertTrue(pair.isGeneric)
        // `Value` is bound by the alias itself, not a dependency on an outside type.
        XCTAssertEqual(pair.dependencies.count, 0)
    }

    func testSubscriptsAndDeinitializersAreExtracted() {
        let file = parse("""
        struct Matrix {
            subscript(row: Int) -> Double { get { 0 } set {} }
            subscript(flat index: Int) -> Double { 0 }
        }
        final class Session {
            deinit { socket.close() }
        }
        """)

        let matrix = file.structs[0]
        XCTAssertEqual(matrix.subscripts.count, 2)
        XCTAssertTrue(matrix.subscripts[0].isSettable)
        XCTAssertFalse(matrix.subscripts[1].isSettable)
        XCTAssertEqual(matrix.subscripts[1].accessors, ["get"])
        XCTAssertEqual(matrix.subscripts[0].returnType, "Double")
        // The subscript's types are part of what the enclosing type depends on.
        XCTAssertTrue(matrix.dependencies.containsDependency(name: "Double"))

        XCTAssertEqual(file.classes[0].deinitializers.count, 1)
    }

    func testAssociatedTypesAreExtracted() {
        let file = parse("""
        protocol Repository {
            associatedtype Entity: Identifiable
            associatedtype Failure: Error = NetworkError
        }
        """)

        let repository = file.protocols[0]
        XCTAssertEqual(repository.associatedTypes.map(\.name), ["Entity", "Failure"])
        XCTAssertTrue(repository.hasAssociatedType(named: "Entity"))
        XCTAssertEqual(repository.associatedTypes[0].inheritedTypes, ["Identifiable"])
        XCTAssertEqual(repository.associatedTypes[1].defaultType, "NetworkError")
    }

    func testMacrosOperatorsAndPrecedenceGroupsAreExtracted() {
        let file = parse("""
        precedencegroup PipelinePrecedence {
            associativity: left
            assignment: false
            higherThan: AdditionPrecedence
        }
        infix operator |>: PipelinePrecedence
        postfix operator ^^
        @freestanding(expression)
        public macro stringify<V>(_ value: V) -> (V, String) = #externalMacro(module: "M", type: "S")
        """)

        XCTAssertEqual(file.macros.map(\.name), ["stringify"])
        XCTAssertEqual(file.macros[0].parameters.map(\.name), ["value"])
        XCTAssertEqual(file.macros[0].returnType, "(V, String)")

        XCTAssertEqual(file.operators.map(\.name), ["|>", "^^"])
        XCTAssertEqual(file.operators[0].fixity, .infix)
        XCTAssertEqual(file.operators[0].precedenceGroup, "PipelinePrecedence")
        XCTAssertEqual(file.operators[1].fixity, .postfix)
        XCTAssertNil(file.operators[1].precedenceGroup)

        let group = file.precedenceGroups[0]
        XCTAssertEqual(group.name, "PipelinePrecedence")
        XCTAssertEqual(group.associativity, "left")
        XCTAssertFalse(group.isAssignment)
        XCTAssertEqual(group.higherThan, ["AdditionPrecedence"])
    }

    // MARK: - Conditional compilation

    func testEveryConditionalBranchIsCollected() {
        let file = parse("""
        #if os(iOS)
        class PlatformView: UIView {}
        #else
        class PlatformView: NSView {}
        #endif

        struct Wrapper {
            #if DEBUG
            let probe: Probe
            #endif
        }
        """)

        // The parser has no build configuration, so filtering to one branch would mean
        // guessing. Both are reported, and a rule sees the union.
        XCTAssertEqual(file.classes.map(\.superClass), ["UIView", "NSView"])
        XCTAssertEqual(file.structs[0].properties.map(\.name), ["probe"])
    }

    // MARK: - Modifiers

    func testPreviouslyDroppedModifiersAreRecorded() {
        let file = parse("""
        public final class Cache {
            package lazy var store: Store = Store()
            unowned let owner: Owner
            dynamic func refresh() {}
            nonisolated var id: String { "" }
        }
        indirect enum Tree { case node(Tree) }
        """)

        let cache = file.classes[0]
        XCTAssertTrue(cache.properties[0].hasModifier(.package))
        XCTAssertTrue(cache.properties[0].hasModifier(.lazy))
        XCTAssertTrue(cache.properties[1].hasModifier(.unowned))
        XCTAssertTrue(cache.properties[2].hasModifier(.nonisolated))
        XCTAssertTrue(cache.methods[0].hasModifier(.dynamic))
        XCTAssertTrue(file.enums[0].hasModifier(.indirect))
    }

    func testUnrecognizedModifierIsPreservedRatherThanDropped() {
        // A modifier the enum does not know must not make a declaration look *less*
        // restricted than it is, so it is kept verbatim.
        let modifier = SwiftModifier(rawValue: "someFutureKeyword")

        XCTAssertEqual(modifier, .unknown("someFutureKeyword"))
        XCTAssertEqual(modifier.rawValue, "someFutureKeyword")
        XCTAssertFalse(modifier.isKnown)
        XCTAssertTrue(SwiftModifier(rawValue: "public").isKnown)
        XCTAssertEqual(SwiftModifier(rawValue: "public"), .public)
    }

    // MARK: - Scope and filtering API

    func testScopeExposesNestedAndTopLevelTypes() throws {
        let directory = try makeScope("""
        struct Outer {
            struct Inner {}
        }
        actor Worker {}
        typealias Handler = () -> Void
        """)
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let scope = try Conformant.scope(directory: directory)

        XCTAssertEqual(scope.actors().map(\.name), ["Worker"])
        XCTAssertEqual(scope.typealiases().map(\.name), ["Handler"])
        XCTAssertEqual(scope.nestedTypes().map(\.name), ["Outer.Inner"])
        XCTAssertEqual(Set(scope.topLevelTypes().map(\.name)), ["Outer", "Worker"])
        XCTAssertEqual(scope.structs().withParent("Outer").map(\.name), ["Outer.Inner"])
        XCTAssertEqual(scope.structs().topLevel().map(\.name), ["Outer"])
        XCTAssertEqual(scope.structs().nested().map(\.name), ["Outer.Inner"])
        XCTAssertTrue(scope.types().contains { $0.name == "Worker" })
    }

    // MARK: - Helpers

    private func makeScope(_ source: String) throws -> String {
        let directory = NSTemporaryDirectory() + "conformant-coverage-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try source.write(toFile: directory + "/Source.swift", atomically: true, encoding: .utf8)
        return directory
    }
}
