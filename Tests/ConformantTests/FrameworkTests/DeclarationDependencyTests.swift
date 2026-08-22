import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class DeclarationDependencyTests: XCTestCase {
    func testImportDependencies() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = try Conformant.scope(directory: testFilesDirectory)
        let files = scope.files()

        let foundationImports = files.flatMap { $0.imports }.filter { $0.name == "Foundation" }
        XCTAssertGreaterThanOrEqual(foundationImports.count, 3)

        let importDependencies = files.flatMap { $0.importDependencies }
        XCTAssertTrue(importDependencies.contains { $0.name == "Foundation" && $0.kind == .import })

        if let location = importDependencies.first(where: { $0.name == "Foundation" })?.location {
            XCTAssertGreaterThan(location.line, 0)
            XCTAssert(location.file.contains("NetworkService.swift") || location.file.contains("NetworkConfiguration.swift") || location.file.contains("NetworkProtocols.swift"))
        } else {
            XCTFail("Foundation import dependency not found")
        }
    }

    func testClassDependencies() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = try Conformant.scope(directory: testFilesDirectory)
        guard let serviceClass = scope.classes().first(where: { $0.name == "NetworkService" }) else {
            XCTFail("NetworkService class not found")
            return
        }

        let deps = serviceClass.dependencies

        XCTAssertFalse(deps.containsDependency(kind: .inheritance))
        XCTAssertFalse(deps.containsDependency(kind: .conformance))

        XCTAssertTrue(deps.containsDependency(name: "URL", kind: .typeUsage), "Should depend on URL")
        XCTAssertTrue(deps.containsDependency(name: "URLSession", kind: .typeUsage), "Should depend on URLSession")
        XCTAssertTrue(deps.containsDependency(name: "Bool", kind: .typeUsage), "Should depend on Bool")
        XCTAssertTrue(deps.containsDependency(name: "String", kind: .typeUsage), "Should depend on String")
        XCTAssertTrue(deps.containsDependency(name: "Data", kind: .typeUsage), "Should depend on Data")
        XCTAssertTrue(deps.containsDependency(name: "Error", kind: .typeUsage), "Should depend on Error")
        // From fetchData completion
        XCTAssertTrue(deps.containsDependency(name: "Result", kind: .typeUsage), "Should depend on Result")
        // From configure method
        XCTAssertTrue(deps.containsDependency(name: "URLSessionConfiguration", kind: .typeUsage), "Should depend on URLSessionConfiguration")

        // `static let shared = NetworkService(...)` is a construction, not a mention of a
        // written-down type: the body walker reports it as such rather than inferring a name.
        XCTAssertTrue(deps.containsDependency(name: "NetworkService", kind: .instantiation), "Should depend on NetworkService (static let initializer)")
        XCTAssertTrue(deps.containsDependency(name: "URL", kind: .instantiation), "Should depend on URL (built inside the static let initializer)")
    }

    func testStructDependencies() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = try Conformant.scope(directory: testFilesDirectory)
        guard let configStruct = scope.structs().first(where: { $0.name == "NetworkConfiguration" }) else {
            XCTFail("NetworkConfiguration struct not found")
            return
        }

        let deps = configStruct.dependencies

        XCTAssertTrue(deps.containsDependency(name: "Codable", kind: .conformance), "Should conform to Codable")
        XCTAssertTrue(deps.containsDependency(name: "Equatable", kind: .conformance), "Should conform to Equatable")

        XCTAssertTrue(deps.containsDependency(name: "String", kind: .typeUsage), "Should depend on String")
        XCTAssertTrue(deps.containsDependency(name: "TimeInterval", kind: .typeUsage), "Should depend on TimeInterval")
        // `URLRequest.CachePolicy` is one dependency, and it answers to its own name and
        // to the trailing part of it — but not to the qualifier on its own.
        XCTAssertTrue(deps.containsDependency(name: "URLRequest.CachePolicy", kind: .typeUsage))
        XCTAssertTrue(deps.containsDependency(name: "CachePolicy", kind: .typeUsage))
        XCTAssertFalse(deps.containsDependency(name: "URLRequest", kind: .typeUsage), "The source never named URLRequest by itself")
        XCTAssertTrue(deps.containsDependency(name: "URLSessionConfiguration", kind: .typeUsage), "Should depend on URLSessionConfiguration")
        XCTAssertTrue(deps.containsDependency(name: "NetworkConfiguration", kind: .typeUsage), "Should depend on NetworkConfiguration (static properties/==)")
    }

    func testProtocolDependencies() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = try Conformant.scope(directory: testFilesDirectory)
        guard let serviceProvider = scope.protocols().first(where: { $0.name == "NetworkServiceProvider" }) else {
            XCTFail("NetworkServiceProvider protocol not found")
            return
        }

        let deps = serviceProvider.dependencies

        XCTAssertFalse(deps.containsDependency(kind: .inheritance))
        XCTAssertFalse(deps.containsDependency(kind: .conformance))

        XCTAssertTrue(deps.containsDependency(name: "URL", kind: .typeUsage), "Should depend on URL")
        XCTAssertTrue(deps.containsDependency(name: "URLSession", kind: .typeUsage), "Should depend on URLSession")
        XCTAssertTrue(deps.containsDependency(name: "String", kind: .typeUsage), "Should depend on String")
        XCTAssertTrue(deps.containsDependency(name: "Data", kind: .typeUsage), "Should depend on Data")
        XCTAssertTrue(deps.containsDependency(name: "Error", kind: .typeUsage), "Should depend on Error")
        XCTAssertTrue(deps.containsDependency(name: "Result", kind: .typeUsage), "Should depend on Result")

        // --- Test Configurable ---
        guard let configurable = scope.protocols().first(where: { $0.name == "Configurable" }) else {
            XCTFail("Configurable protocol not found")
            return
        }

        let configDeps = configurable.dependencies
        XCTAssertFalse(
            configDeps.containsDependency(name: "Configuration", kind: .typeUsage),
            "Configuration is the protocol's own associated type, not a type it depends on"
        )
    }

    func testExtensionDependencies() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = try Conformant.scope(directory: testFilesDirectory)
        guard let serviceExtension = scope.extensions().first(where: { $0.name == "NetworkService" }) else {
            XCTFail("NetworkService extension not found")
            return
        }

        let deps = serviceExtension.dependencies

        XCTAssertTrue(deps.containsDependency(name: "NetworkService", kind: .extension), "Should depend on NetworkService (extension target)")
        XCTAssertFalse(deps.containsDependency(kind: .conformance))
        XCTAssertTrue(deps.containsDependency(name: "String", kind: .typeUsage), "Should depend on String")
        XCTAssertTrue(deps.containsDependency(name: "Data", kind: .typeUsage), "Should depend on Data")
    }

    // MARK: - Structured type resolution

    /// The names a written type contributes as dependencies, read back through the
    /// parser rather than through a string splitter, so the assertions describe what a
    /// rule would actually see.
    private func dependencyNames(ofPropertyTyped type: String) -> [String] {
        let file = SwiftSyntaxParser().parse(
            source: "struct Probe { var value: \(type) }",
            path: "Probe.swift"
        )
        return file.structs.first?.dependencies.map(\.name) ?? []
    }

    func testWrittenTypesResolveToTheNamesTheyMention() {
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "String"), ["String"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "String?"), ["String"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "String!"), ["String"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "[Int]"), ["Int"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "[String: Int]"), ["String", "Int"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "Optional<URLSession>"), ["Optional", "URLSession"])
        XCTAssertEqual(
            dependencyNames(ofPropertyTyped: "(Result<MyType, MyError>) -> Void"),
            ["Result", "MyType", "MyError", "Void"]
        )
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "any Equatable"), ["Equatable"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "some View"), ["View"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "Codable & Sendable"), ["Codable", "Sendable"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "Int.Type"), ["Int"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "(Int, Label)"), ["Int", "Label"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "@Sendable (Int) -> Void"), ["Int", "Void"])
    }

    func testQualifiedNameIsOneDependencyRatherThanTwo() {
        // The whole point of the structured walker: `MyModule.MyType` is one type, not a
        // dependency on a module plus a dependency on a name.
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "MyModule.MyType"), ["MyModule.MyType"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "Swift.Int"), ["Swift.Int"])
        XCTAssertEqual(dependencyNames(ofPropertyTyped: "A.B.C"), ["A.B.C"])
        XCTAssertEqual(
            dependencyNames(ofPropertyTyped: "Swift.Array<MyModule.Element>"),
            ["Swift.Array", "MyModule.Element"]
        )
    }

    func testQualifiedDependencyMatchesAnyTrailingPartOfItsName() {
        let file = SwiftSyntaxParser().parse(
            source: "struct Probe { var value: MyModule.Deep.Type1 }",
            path: "Probe.swift"
        )
        let dependencies = try? XCTUnwrap(file.structs.first).dependencies

        XCTAssertTrue(dependencies?.containsDependency(name: "MyModule.Deep.Type1") ?? false)
        XCTAssertTrue(dependencies?.containsDependency(name: "Deep.Type1") ?? false)
        XCTAssertTrue(dependencies?.containsDependency(name: "Type1") ?? false)
        XCTAssertFalse(dependencies?.containsDependency(name: "Deep") ?? true)
        XCTAssertFalse(dependencies?.containsDependency(name: "Type") ?? true)
    }

    func testGenericParametersAndAssociatedTypesAreNotDependencies() {
        let file = SwiftSyntaxParser().parse(
            source: """
            struct Box<Element> {
                var contents: [Element]
                var label: String
                func map<Other>(_ transform: (Element) -> Other) -> Box<Other> { fatalError() }
            }

            protocol Repository {
                associatedtype Entity: Identifiable
                subscript(id: Entity.ID) -> Entity? { get }
                func store(_ entity: Entity) throws
            }
            """,
            path: "Generics.swift"
        )

        let box = file.structs.first { $0.name == "Box" }
        // `Element` and `Other` are placeholders; `Box` is a real self-reference.
        XCTAssertEqual(box?.dependencies.map(\.name), ["String", "Box"])

        let repository = file.protocols.first { $0.name == "Repository" }
        // `Entity` and `Entity.ID` are placeholders; only the real constraint remains.
        XCTAssertEqual(repository?.dependencies.map(\.name), ["Identifiable"])
    }

    func testSelfIsNotADependency() {
        let file = SwiftSyntaxParser().parse(
            source: "struct Point { static func zero() -> Self { fatalError() } }",
            path: "Point.swift"
        )
        XCTAssertEqual(file.structs.first?.dependencies.map(\.name), [])
    }

    func testReferenceRecordsHowTheTypeWasWritten() {
        let file = SwiftSyntaxParser().parse(
            source: "struct Probe { var value: [Foundation.URL]? }",
            path: "Probe.swift"
        )
        let reference = file.structs.first?.dependencies.first?.reference

        XCTAssertEqual(reference?.baseName, "URL")
        XCTAssertEqual(reference?.qualifiedName, "Foundation.URL")
        XCTAssertEqual(reference?.moduleQualifier, "Foundation")
        // The array is the innermost sugar around the name, so that is the form recorded.
        XCTAssertEqual(reference?.form, .array)
    }

    func testStandardLibraryFilterIsOffByDefault() {
        let source = "struct Probe { var value: [String: Int] }"

        let unfiltered = SwiftSyntaxParser().parse(source: source, path: "Probe.swift")
        XCTAssertEqual(unfiltered.structs.first?.dependencies.map(\.name), ["String", "Int"])

        let filtered = SwiftSyntaxParser(ignoresStandardLibraryTypes: true)
            .parse(source: source, path: "Probe.swift")
        XCTAssertEqual(filtered.structs.first?.dependencies.map(\.name), [])
    }

    private func classDependencies(_ source: String,
                                   depth: ScopePolicy.DependencyDepth = .signaturesAndBodies) -> [String] {
        let file = SwiftSyntaxParser(dependencyDepth: depth).parse(source: source, path: "Probe.swift")
        return (file.classes.first?.dependencies ?? []).map { "\($0.name)/\($0.kind)" }
    }

    func testBodiesReportWhatTheyConstructAndReachFor() {
        // A signature says what a declaration promises; a body says what it actually uses.
        // `UserRepository()` couples `Controller` to `UserRepository` as firmly as a stored
        // property would, and a layer rule that could not see it would pass while the
        // coupling it exists to catch went unreported.
        XCTAssertEqual(
            classDependencies("""
            final class Controller {
                func run() {
                    let repository = UserRepository()
                    DatabaseClient.shared.connect()
                    let value = Parser.parse("x") as? ParsedValue
                    _ = repository
                    _ = value
                }
            }
            """),
            [
                "UserRepository/instantiation",
                "DatabaseClient/staticAccess",
                "Parser/staticAccess",
                "ParsedValue/typeUsage",
            ]
        )
    }

    func testDottedChainNamesTheTypeAndNotItsMembers() {
        // `A.b.c()` is one mention of `A`, not three dependencies. The split follows Swift's
        // capitalization convention: the leading run of capitalized components is the type.
        XCTAssertEqual(
            classDependencies("final class C { func f() { Notification.Name.didChange.hashValue.hash() } }"),
            ["Notification.Name/staticAccess"]
        )
        // A capitalized *member* breaks that convention and reads as a nested type. This is
        // the documented cost of a syntactic walker: it reports what was written.
        XCTAssertEqual(
            classDependencies("final class C { func f() { _ = Notification.Name.NSCalendarDayChanged } }"),
            ["Notification.Name.NSCalendarDayChanged/staticAccess"]
        )
        // Nothing capitalized at the root means nothing that reads as a type.
        XCTAssertEqual(classDependencies("final class C { func f() { print(items.count) } }"), [])
    }

    func testLocalBindingsAreNotDependencies() {
        // A name bound in the body is the body's own, not a type it reaches for.
        XCTAssertEqual(
            classDependencies("""
            final class C {
                func f() {
                    let Handler = 1
                    _ = Handler
                }
            }
            """),
            []
        )
    }

    func testDeinitializerBodiesAreRead() {
        // `deinit` has no signature at all, so its body is the only place its coupling shows.
        XCTAssertEqual(
            classDependencies("final class Resource { deinit { Telemetry.record() } }"),
            ["Telemetry/staticAccess"]
        )
    }

    func testGenericConstraintsAreDependencies() {
        // A generic parameter is a placeholder, but the bound written on it names a real
        // type: `func send<T: Codable>` depends on `Codable`.
        XCTAssertEqual(
            classDependencies("""
            final class Service {
                func send<T: Codable>(_ value: T) where T: Sendable {}
                func same<V>(_ value: V) where V == Token {}
            }
            """),
            [
                "Codable/genericConstraint",
                "Sendable/genericConstraint",
                "Token/genericConstraint",
            ]
        )
    }

    func testDependencyDepthSignaturesStopsAtTheSignature() {
        let source = "final class Box { func make() -> Widget { Widget(Gear()) } }"

        // Bodies are strictly more information, so the two depths differ only by addition.
        XCTAssertEqual(
            classDependencies(source),
            ["Widget/typeUsage", "Widget/instantiation", "Gear/instantiation"]
        )
        XCTAssertEqual(classDependencies(source, depth: .signatures), ["Widget/typeUsage"])
    }

    func testOnlyTypeCouplingKindsAreSubjectToLayerRules() {
        // Layer rules ask this question of every dependency, so a kind that answered wrongly
        // would make a rule pass over real coupling.
        for kind in [DependencyKind.inheritance, .conformance, .typeUsage,
                     .instantiation, .staticAccess, .genericConstraint] {
            XCTAssertTrue(kind.couplesToType, "\(kind) names a type the declaration reaches for")
        }
        // Imports are matched by module name on their own path, and an extension's subject is
        // the declaration itself rather than something it reaches out to.
        XCTAssertFalse(DependencyKind.import.couplesToType)
        XCTAssertFalse(DependencyKind.extension.couplesToType)
    }

    func testComplexTypeDependencies() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = try Conformant.scope(directory: testFilesDirectory)
        guard let complexStruct = scope.structs().first(where: { $0.name == "ComplexTypes" }) else {
            XCTFail("ComplexTypes struct not found")
            return
        }

        // Test dependencies extracted by the basic helper
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "String", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Int", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Foundation.URL", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "URL", kind: .typeUsage))
        XCTAssertFalse(
            complexStruct.dependencies.containsDependency(name: "Foundation", kind: .typeUsage),
            "Foundation.URL is one type, not a dependency on a module plus a dependency on a name"
        )
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Result", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "MyType", kind: .typeUsage)) // User-defined type
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Error", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Void", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "CustomStringConvertible", kind: .typeUsage)) // From tuple label

        // --- Test Enum ---
        guard let statusEnum = scope.enums().first(where: { $0.name == "Status" }) else {
            XCTFail("Status enum not found")
            return
        }

        // Generic constraint. A bound on the enum's own type parameter is not a conformance
        // the enum declares — it is a requirement it places on a caller's type.
        XCTAssertTrue(statusEnum.dependencies.containsDependency(name: "Equatable", kind: .genericConstraint)) // From generic constraint T: Equatable
        // Raw Type
        XCTAssertTrue(statusEnum.dependencies.containsDependency(name: "String", kind: .typeUsage)) // From ': String' raw type
        // Associated Values
        XCTAssertTrue(statusEnum.dependencies.containsDependency(name: "Error", kind: .typeUsage)) // From .failure(Error)
        // Generic type T itself isn't tracked as a dependency here
        XCTAssertFalse(statusEnum.dependencies.containsDependency(name: "T", kind: .typeUsage))
    }
}

extension DeclarationDependencyTests {
    func makeSUT() throws -> String {
        let testFilesDirectory = NSTemporaryDirectory() + "DeclarationDependencyTests_" + UUID().uuidString

        try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)

        try createClassFile(testFilesDirectory)
        try createStructFile(testFilesDirectory)
        try createProtocolFile(testFilesDirectory)
        try createComplexTypesFile(testFilesDirectory)

        return testFilesDirectory
    }

    func cleanup(_ testFilesDirectory: String) {
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }

    private func createClassFile(_ testFilesDirectory: String) throws {
        let classContent = """
         import Foundation
         
         // Class Dependency: None (no superclass)
         // Protocol Dependencies: None
         public final class NetworkService {
             // Property Dependencies: URL, URLSession, Bool
             private let baseURL: URL
             private let session: URLSession
             public var isActive: Bool = false
             public static let shared = NetworkService(baseURL: URL(string: "https://api.example.com")!) // Instantiation: NetworkService, URL
         
             // Method Dependencies: URL, URLSession, String, Result, Data, Error, NSError, Void (@escaping is trivia)
             public init(baseURL: URL, session: URLSession = .shared) {
                 self.baseURL = baseURL
                 self.session = session
             }
         
             public func fetchData(from endpoint: String, completion: @escaping (Result<Data, Error>) -> Void) { }
         
             @available(iOS 14.0, *) 
             public func cancelAllRequests() { } // TypeUsage: URLSessionTask? (inferred, not tracked yet)
         
             internal func configure(with configuration: URLSessionConfiguration) { } // TypeUsage: URLSessionConfiguration
         }
         
         // Extension Dependency: NetworkService
         // Protocol Dependencies (Extension): None
         extension NetworkService {
              // Method Dependencies: String, Data, URL, URLSession
             public func get(from endpoint: String) async throws -> Data { return Data() }
         
             // Method Dependencies: String, Data, URL, URLRequest, URLSession
             public func post(to endpoint: String, body: Data) async throws -> Data { return Data() }
         }
         """

        try classContent.write(toFile: testFilesDirectory + "/NetworkService.swift", atomically: true, encoding: .utf8)
    }

    private func createStructFile(_ testFilesDirectory: String) throws {
        let structContent = """
        import Foundation
        
        // Protocol Dependencies: Codable, Equatable
        public struct NetworkConfiguration: Codable, Equatable {
            // Property Dependencies: String, TimeInterval, URLRequest.CachePolicy (-> URLRequest, CachePolicy)
            public let apiKey: String
            public var timeoutInterval: TimeInterval
            public var cachePolicy: URLRequest.CachePolicy
            public var defaultHeaders: [String: String] // TypeUsage: String
        
            // Init Dependencies: String, TimeInterval, URLRequest.CachePolicy
            public init(apiKey: String, timeoutInterval: TimeInterval = 30.0, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, defaultHeaders: [String: String] = [:]) { }
        
            // Method Dependencies: URLSessionConfiguration, TimeInterval, URLRequest.CachePolicy, String
            public func makeSessionConfiguration() -> URLSessionConfiguration { return .default }
        
            // Property Dependencies: NetworkConfiguration, String, TimeInterval
            public static let development = NetworkConfiguration(apiKey: "dev")
            public static let production = NetworkConfiguration(apiKey: "prod")
        
            // Method Dependencies: NetworkConfiguration, Bool
            public static func == (lhs: NetworkConfiguration, rhs: NetworkConfiguration) -> Bool { return true }
        }
        """

        try structContent.write(toFile: testFilesDirectory + "/NetworkConfiguration.swift", atomically: true, encoding: .utf8)
    }

    private func createProtocolFile(_ testFilesDirectory: String) throws {
        let protocolContent = """
        import Foundation
        
        // Protocol Dependencies: None
        public protocol NetworkServiceProvider {
            // Property Dependencies: URL, URLSession
            var baseURL: URL { get }
            var session: URLSession { get }
        
            // Method Dependencies: String, Result, Data, Error, Void (@escaping)
            func fetchData(from endpoint: String, completion: @escaping (Result<Data, Error>) -> Void)
            // Method Dependencies: String, Data
            func get(from endpoint: String) async throws -> Data
            func post(to endpoint: String, body: Data) async throws -> Data
            // Method Dependencies: None
            func cancelAllRequests()
        }
        
        // Protocol Dependencies: None
        public protocol RequestAuthenticator {
             // Method Dependencies: URLRequest
            func authenticate(request: URLRequest) -> URLRequest
            // Method Dependencies: Bool
            func refreshCredentials() async throws -> Bool
        }
        
        // Protocol Dependencies: None
        public protocol Configurable {
            // AssociatedType Dependency: Not currently tracked via SwiftDependency
            associatedtype Configuration
            // Method Dependencies: Configuration (assoc type, not tracked), Void
            func configure(with configuration: Configuration)
        }
        """
        try protocolContent.write(toFile: testFilesDirectory + "/NetworkProtocols.swift", atomically: true, encoding: .utf8)
    }

    private func createComplexTypesFile(_ testFilesDirectory: String) throws {
        let content = """
         struct ComplexTypes {
             var optionalString: String?
             var dict: [String: Int]?
             var array: [Foundation.URL]
             var closure: (Result<MyType, Error>) -> Void
             var tuple: (Int, label: CustomStringConvertible)?
         }
         enum Status<T: Equatable>: String { // Generic param, conformance, raw type
             case success(T) // Associated value
             case failure(Error)
         }
         """
        try content.write(toFile: testFilesDirectory + "/ComplexTypes.swift", atomically: true, encoding: .utf8)
    }

}
