import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class DeclarationDependencyTests: XCTestCase {
    var testFilesDirectory: String!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testFilesDirectory = NSTemporaryDirectory() + "DeclarationDependencyTests_" + UUID().uuidString

        try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)

        try createClassFile()
        try createStructFile()
        try createProtocolFile()
        try createComplexTypesFile()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }

    // MARK: - Test File Creation Helpers (Copied & Adapted)

    private func createClassFile() throws {
        let classContent = """
         import Foundation
         
         // Class Dependency: None (no superclass)
         // Protocol Dependencies: None
         public final class NetworkService {
             // Property Dependencies: URL, URLSession, Bool
             private let baseURL: URL
             private let session: URLSession
             public var isActive: Bool = false
             public static let shared = NetworkService(baseURL: URL(string: "https://api.example.com")!) // TypeUsage: NetworkService, URL, String
         
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

    private func createStructFile() throws {
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

    private func createProtocolFile() throws {
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

    private func createComplexTypesFile() throws {
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

    // MARK: - Dependency Tests

    func testImportDependencies() throws {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
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
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
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

        XCTAssertTrue(deps.containsDependency(name: "NetworkService", kind: .typeUsage), "Should depend on NetworkService (static let type)")
    }

    func testStructDependencies() throws {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        guard let configStruct = scope.structs().first(where: { $0.name == "NetworkConfiguration" }) else {
            XCTFail("NetworkConfiguration struct not found")
            return
        }

        let deps = configStruct.dependencies

        XCTAssertTrue(deps.containsDependency(name: "Codable", kind: .conformance), "Should conform to Codable")
        XCTAssertTrue(deps.containsDependency(name: "Equatable", kind: .conformance), "Should conform to Equatable")

        XCTAssertTrue(deps.containsDependency(name: "String", kind: .typeUsage), "Should depend on String")
        XCTAssertTrue(deps.containsDependency(name: "TimeInterval", kind: .typeUsage), "Should depend on TimeInterval")
        XCTAssertTrue(deps.containsDependency(name: "URLRequest", kind: .typeUsage), "Should depend on URLRequest (from CachePolicy)") // Depends on extractTypeNames
        XCTAssertTrue(deps.containsDependency(name: "CachePolicy", kind: .typeUsage), "Should depend on CachePolicy (from URLRequest.CachePolicy)") // Depends on extractTypeNames
        XCTAssertTrue(deps.containsDependency(name: "URLSessionConfiguration", kind: .typeUsage), "Should depend on URLSessionConfiguration")
        XCTAssertTrue(deps.containsDependency(name: "NetworkConfiguration", kind: .typeUsage), "Should depend on NetworkConfiguration (static properties/==)")
    }

    func testProtocolDependencies() throws {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
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
        XCTAssertTrue(configDeps.containsDependency(name: "Configuration", kind: .typeUsage), "Should depend on Configuration assoc type name")
    }

    func testExtensionDependencies() throws {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
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

    func testExtractTypeNamesHelper() {
        let visitor = SwiftSyntaxVisitor(
            filePath: "dummy",
            converter: SourceLocationConverter(
                fileName: "dummy",
                tree: SourceFileSyntax(statements: [])
            )
        )

        XCTAssertEqual(visitor.extractTypeNames(from: "String"), ["String"])
        XCTAssertEqual(visitor.extractTypeNames(from: "String?"), ["String"])
        XCTAssertEqual(visitor.extractTypeNames(from: "[Int]"), ["Int"])
        XCTAssertEqual(visitor.extractTypeNames(from: "[String: Int]"), ["String", "Int"])
        XCTAssertEqual(visitor.extractTypeNames(from: "Optional<URLSession>"), ["Optional", "URLSession"])
        XCTAssertEqual(visitor.extractTypeNames(from: "(Result<MyType, MyError>) -> Void"), ["Result", "MyType", "MyError", "Void"]) // Current basic logic
        XCTAssertEqual(visitor.extractTypeNames(from: "MyModule.MyType"), ["MyModule", "MyType"])
        // Assuming 'any'/'some' are added later or handled
        XCTAssertEqual(visitor.extractTypeNames(from: "any Equatable"), ["Equatable"])
        XCTAssertEqual(visitor.extractTypeNames(from: "T"), ["T"])
    }

    func testComplexTypeDependencies() throws {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        guard let complexStruct = scope.structs().first(where: { $0.name == "ComplexTypes" }) else {
            XCTFail("ComplexTypes struct not found")
            return
        }

        // Test dependencies extracted by the basic helper
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "String", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Int", kind: .typeUsage))
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "URL", kind: .typeUsage)) // From Foundation.URL
        XCTAssertTrue(complexStruct.dependencies.containsDependency(name: "Foundation", kind: .typeUsage)) // From Foundation.URL
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

        // Conformance
        XCTAssertTrue(statusEnum.dependencies.containsDependency(name: "Equatable", kind: .conformance)) // From generic constraint T: Equatable
        // Raw Type
        XCTAssertTrue(statusEnum.dependencies.containsDependency(name: "String", kind: .typeUsage)) // From ': String' raw type
        // Associated Values
        XCTAssertTrue(statusEnum.dependencies.containsDependency(name: "Error", kind: .typeUsage)) // From .failure(Error)
        // Generic type T itself isn't tracked as a dependency here
        XCTAssertFalse(statusEnum.dependencies.containsDependency(name: "T", kind: .typeUsage))
    }
}
