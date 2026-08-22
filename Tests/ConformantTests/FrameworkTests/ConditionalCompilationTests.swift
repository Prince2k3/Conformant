//
//  ConditionalCompilationTests.swift
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
import SwiftParser
import SwiftSyntax
@testable import Conformant

/// `#if` branches, and which of them a scope reads.
///
/// The default reads all of them. `.activeBranch(_:)` reads only the ones the described
/// build compiles and, crucially, keeps any branch whose condition the configuration
/// cannot answer. Dropping a branch that might compile would hide declarations from
/// every rule, and a rule with nothing to check passes.
final class ConditionalCompilationTests: XCTestCase {

    private let platformSource = """
    #if canImport(UIKit)
    struct PlatformView {}
    #elseif canImport(AppKit)
    struct DesktopView {}
    #else
    struct HeadlessView {}
    #endif
    """

    // MARK: - Policy

    func testAllBranchesIsTheDefault() {
        XCTAssertEqual(structNames(platformSource), ["DesktopView", "HeadlessView", "PlatformView"])
    }

    func testActiveBranchKeepsOnlyTheBranchTheBuildCompiles() {
        let names = structNames(
            platformSource,
            BuildConfiguration(importableModules: ["UIKit", "Foundation"])
        )
        XCTAssertEqual(names, ["PlatformView"])
    }

    func testAFailedBranchFallsThroughToTheNextOne() {
        let names = structNames(
            platformSource,
            BuildConfiguration(importableModules: ["AppKit"])
        )
        XCTAssertEqual(names, ["DesktopView"])
    }

    func testElseIsTakenWhenEveryConditionFails() {
        let names = structNames(platformSource, BuildConfiguration(importableModules: []))
        XCTAssertEqual(names, ["HeadlessView"])
    }

    func testAnUnanswerableConditionKeepsItsBranchAndTheOnesBelow() {
        // No module list, so `canImport` cannot be answered at all. Everything stays,
        // which is the same as `.allBranches`, the safe direction.
        let names = structNames(platformSource, BuildConfiguration(operatingSystem: "iOS"))
        XCTAssertEqual(names, ["DesktopView", "HeadlessView", "PlatformView"])
    }

    func testABranchBelowAnUndecidedOneIsStillDroppedWhenItDefinitelyFails() {
        let source = """
        #if canImport(UIKit)
        struct Unknown {}
        #elseif os(Linux)
        struct Penguin {}
        #else
        struct Fallback {}
        #endif
        """
        // `canImport` is unanswerable, so its branch stays and the search continues.
        // `os(Linux)` is answerable and false, so that branch goes; `#else` stays,
        // because nothing above it definitely held.
        XCTAssertEqual(structNames(source, BuildConfiguration(operatingSystem: "iOS")), ["Fallback", "Unknown"])
    }

    // MARK: - Predicates

    func testCustomFlagsAreDecidedByTheConfiguration() {
        let source = """
        #if DEBUG
        struct Debugging {}
        #else
        struct Shipping {}
        #endif
        """
        XCTAssertEqual(structNames(source, BuildConfiguration(customFlags: ["DEBUG"])), ["Debugging"])
        // An unlisted flag reads as unset rather than unknown: whoever writes the
        // configuration knows the whole `-D` set, just as the compiler does.
        XCTAssertEqual(structNames(source, BuildConfiguration()), ["Shipping"])
    }

    func testOperatingSystemArchitectureAndEnvironment() {
        let configuration = BuildConfiguration(
            operatingSystem: "iOS",
            architecture: "arm64",
            targetEnvironment: "simulator"
        )
        XCTAssertEqual(evaluate("os(iOS)", configuration), .yes)
        XCTAssertEqual(evaluate("os(macOS)", configuration), .no)
        XCTAssertEqual(evaluate("arch(arm64)", configuration), .yes)
        XCTAssertEqual(evaluate("arch(x86_64)", configuration), .no)
        XCTAssertEqual(evaluate("targetEnvironment(simulator)", configuration), .yes)
        XCTAssertEqual(evaluate("targetEnvironment(macCatalyst)", configuration), .no)
        // An unset field is undecided, not false.
        XCTAssertEqual(evaluate("os(iOS)", BuildConfiguration()), .undecided)
        XCTAssertEqual(evaluate("targetEnvironment(simulator)", BuildConfiguration()), .undecided)
    }

    func testCanImportReadsTheRootModule() {
        let configuration = BuildConfiguration(importableModules: ["UIKit"])
        XCTAssertEqual(evaluate("canImport(UIKit)", configuration), .yes)
        XCTAssertEqual(evaluate("canImport(UIKit.UIView)", configuration), .yes)
        XCTAssertEqual(evaluate("canImport(AppKit)", configuration), .no)
        XCTAssertEqual(evaluate("canImport(UIKit)", BuildConfiguration()), .undecided)
        // The `_version:` form has a shape this evaluator does not read.
        XCTAssertEqual(evaluate("canImport(UIKit, _version: 1.2)", configuration), .undecided)
    }

    func testVersionComparisons() {
        let configuration = BuildConfiguration(swiftVersion: "6.0", compilerVersion: "6.1")
        XCTAssertEqual(evaluate("swift(>=5.9)", configuration), .yes)
        XCTAssertEqual(evaluate("swift(>=6.0)", configuration), .yes, "6.0 and 6.0.0 are the same version")
        XCTAssertEqual(evaluate("swift(>=6.1)", configuration), .no)
        XCTAssertEqual(evaluate("swift(<6.1)", configuration), .yes)
        XCTAssertEqual(evaluate("swift(<6.0)", configuration), .no)
        XCTAssertEqual(evaluate("compiler(>=6.1)", configuration), .yes)
        XCTAssertEqual(evaluate("swift(>=5.9.1)", configuration), .yes, "A three-component bound still compares")
        XCTAssertEqual(evaluate("swift(>=5.9)", BuildConfiguration()), .undecided)
    }

    func testUnrecognizedPredicatesAreUndecided() {
        let configuration = BuildConfiguration(operatingSystem: "iOS", customFlags: ["DEBUG"])
        XCTAssertEqual(evaluate("hasFeature(RetroactiveAttribute)", configuration), .undecided)
        XCTAssertEqual(evaluate("hasAttribute(retroactive)", configuration), .undecided)
        XCTAssertEqual(evaluate("_endian(little)", configuration), .undecided)
    }

    func testLiteralsAndNegation() {
        let configuration = BuildConfiguration(operatingSystem: "iOS")
        XCTAssertEqual(evaluate("true", configuration), .yes)
        XCTAssertEqual(evaluate("false", configuration), .no)
        XCTAssertEqual(evaluate("!os(iOS)", configuration), .no)
        XCTAssertEqual(evaluate("!os(macOS)", configuration), .yes)
        XCTAssertEqual(evaluate("!canImport(UIKit)", configuration), .undecided)
        XCTAssertEqual(evaluate("(os(iOS))", configuration), .yes)
    }

    // MARK: - Operators

    func testAndOr() {
        let configuration = BuildConfiguration(operatingSystem: "iOS", customFlags: ["DEBUG"])
        XCTAssertEqual(evaluate("os(iOS) && DEBUG", configuration), .yes)
        XCTAssertEqual(evaluate("os(iOS) && RELEASE", configuration), .no)
        XCTAssertEqual(evaluate("os(macOS) || DEBUG", configuration), .yes)
        XCTAssertEqual(evaluate("os(macOS) || RELEASE", configuration), .no)
    }

    func testUndecidedTermsOnlySpreadWhenTheyMatter() {
        let configuration = BuildConfiguration(operatingSystem: "iOS", customFlags: ["DEBUG"])
        // A definite failure settles a conjunction whatever the other term is.
        XCTAssertEqual(evaluate("canImport(UIKit) && os(macOS)", configuration), .no)
        XCTAssertEqual(evaluate("canImport(UIKit) && os(iOS)", configuration), .undecided)
        // A definite success settles a disjunction.
        XCTAssertEqual(evaluate("canImport(UIKit) || DEBUG", configuration), .yes)
        XCTAssertEqual(evaluate("canImport(UIKit) || RELEASE", configuration), .undecided)
    }

    func testAndBindsTighterThanOr() {
        // `#if` conditions reach the evaluator unfolded, as a flat list of operands and
        // operators, so precedence is applied here rather than by the parser.
        let configuration = BuildConfiguration(operatingSystem: "iOS", customFlags: [])
        // true || (false && false) is true; folded left to right,
        // (true || false) && false would be false.
        XCTAssertEqual(evaluate("os(iOS) || DEBUG && os(macOS)", configuration), .yes)
        XCTAssertEqual(evaluate("os(macOS) && DEBUG || os(iOS)", configuration), .yes)
        XCTAssertEqual(evaluate("os(iOS) && DEBUG || os(macOS)", configuration), .no)
    }

    // MARK: - Reach

    func testNestedAndMemberLevelBranchesAreFilteredToo() {
        let source = """
        struct Screen {
            #if os(iOS)
            var touch: Int { 0 }
            #else
            var pointer: Int { 0 }
            #endif
        }
        #if os(iOS)
        #if DEBUG
        struct Inspector {}
        #endif
        #endif
        """
        let file = parse(source, BuildConfiguration(operatingSystem: "iOS", customFlags: ["DEBUG"]))

        XCTAssertEqual(file.structs.first(where: { $0.name == "Screen" })?.properties.map(\.name), ["touch"])
        XCTAssertTrue(file.structs.contains { $0.name == "Inspector" })

        let macOS = parse(source, BuildConfiguration(operatingSystem: "macOS", customFlags: ["DEBUG"]))
        XCTAssertEqual(macOS.structs.first(where: { $0.name == "Screen" })?.properties.map(\.name), ["pointer"])
        XCTAssertFalse(macOS.structs.contains { $0.name == "Inspector" })
    }

    func testDroppedBranchesDropTheirImportsToo() {
        let source = """
        #if canImport(UIKit)
        import UIKit
        #else
        import AppKit
        #endif
        """
        let file = parse(source, BuildConfiguration(importableModules: ["UIKit"]))
        XCTAssertEqual(file.imports.map(\.name), ["UIKit"])
    }

    func testThePolicyReachesScopesBuiltFromDisk() throws {
        let root = NSTemporaryDirectory() + "ConditionalCompilationTests_" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }
        try platformSource.write(
            toFile: (root as NSString).appendingPathComponent("Views.swift"),
            atomically: true,
            encoding: .utf8
        )

        var policy = ScopePolicy.strict
        policy.conditionalCompilation = .activeBranch(BuildConfiguration(importableModules: ["AppKit"]))

        let scope = try Conformant.scope(directory: root, policy: policy)
        XCTAssertEqual(scope.structs().map(\.name), ["DesktopView"])
    }

    // MARK: - Helpers

    private func parse(_ source: String, _ configuration: BuildConfiguration?) -> SwiftFile {
        let parser = SwiftSyntaxParser(
            conditionalCompilation: configuration.map { .activeBranch($0) } ?? .allBranches
        )
        return parser.parse(source: source, path: "Probe.swift")
    }

    private func structNames(_ source: String, _ configuration: BuildConfiguration? = nil) -> [String] {
        parse(source, configuration).structs.map(\.name).sorted()
    }

    /// Evaluates a bare `#if` condition by wrapping it in one.
    private func evaluate(
        _ condition: String,
        _ configuration: BuildConfiguration
    ) -> ConditionalCompilationEvaluator.Answer {
        let source = "#if \(condition)\nstruct Present {}\n#endif"
        let parser = SwiftSyntaxParser(conditionalCompilation: .activeBranch(configuration))
        let present = !parser.parse(source: source, path: "Probe.swift").structs.isEmpty

        // The scope only shows whether the branch was kept, and both `.yes` and
        // `.undecided` keep it. Ask the evaluator directly to tell those apart.
        let sourceFile = Parser.parse(source: source)
        guard let ifConfig = sourceFile.statements.first?.item.as(IfConfigDeclSyntax.self),
              let parsed = ifConfig.clauses.first?.condition
        else {
            XCTFail("Could not parse `#if \(condition)`")
            return .undecided
        }

        let answer = ConditionalCompilationEvaluator(configuration: configuration).evaluate(parsed)
        XCTAssertEqual(present, answer != .no, "`#if \(condition)` kept its branch but evaluated to \(answer)")
        return answer
    }
}
