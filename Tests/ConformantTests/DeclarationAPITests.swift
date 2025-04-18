import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class DeclarationAPITests: XCTestCase {
    
    // Test files directory
    var testFilesDirectory: String!
    
    // Setup - create test files with various Swift declarations
    override func setUp() {
        super.setUp()
        
        // Create a temporary directory for test files
        testFilesDirectory = NSTemporaryDirectory() + "DeclarationAPITests_" + UUID().uuidString

        do {
            try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)
            
            // Create test files
            try createClassFile()
            try createStructFile()
            try createProtocolFile()
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }
    }
    
    // Tear down - remove test files
    override func tearDown() {
        super.tearDown()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }
    
    // MARK: - Test File Creation Helpers
    
    private func createClassFile() throws {
        let classContent = """
        import Foundation
        
        /// A service for handling network requests
        @available(iOS 13.0, *)
        public final class NetworkService {
            // Private properties
            private let baseURL: URL
            private let session: URLSession
            
            /// Flag indicating if the service is active
            public var isActive: Bool = false
            
            // Singleton instance
            public static let shared = NetworkService(baseURL: URL(string: "https://api.example.com")!)
            
            /// Creates a new network service
            /// - Parameter baseURL: The base URL for API requests
            public init(baseURL: URL, session: URLSession = .shared) {
                self.baseURL = baseURL
                self.session = session
            }
            
            /// Fetches data from the specified endpoint
            /// - Parameters:
            ///   - endpoint: API endpoint to fetch
            ///   - completion: Completion handler
            public func fetchData(from endpoint: String, completion: @escaping (Result<Data, Error>) -> Void) {
                let url = baseURL.appendingPathComponent(endpoint)
                let task = session.dataTask(with: url) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let data = data {
                        completion(.success(data))
                    } else {
                        completion(.failure(NSError(domain: "NetworkService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    }
                }
                task.resume()
            }
            
            /// Cancels all ongoing requests
            @available(iOS 14.0, *)
            public func cancelAllRequests() {
                session.getAllTasks { tasks in
                    tasks.forEach { $0.cancel() }
                }
            }
            
            /// Internal method for configuration
            internal func configure(with configuration: URLSessionConfiguration) {
                // Implementation would go here
            }
        }
        
        // Extension to add additional functionality
        extension NetworkService {
            /// Performs a GET request
            public func get(from endpoint: String) async throws -> Data {
                let url = baseURL.appendingPathComponent(endpoint)
                let (data, _) = try await session.data(from: url)
                return data
            }
            
            /// Performs a POST request
            public func post(to endpoint: String, body: Data) async throws -> Data {
                let url = baseURL.appendingPathComponent(endpoint)
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = body
                let (data, _) = try await session.data(for: request)
                return data
            }
        }
        """
        
        try classContent.write(toFile: testFilesDirectory + "/NetworkService.swift", atomically: true, encoding: .utf8)
    }
    
    private func createStructFile() throws {
        let structContent = """
        import Foundation
        
        /// Configuration options for the network service
        public struct NetworkConfiguration: Codable, Equatable {
            /// API key for authentication
            public let apiKey: String
            
            /// Timeout interval in seconds
            public var timeoutInterval: TimeInterval
            
            /// Cache policy for requests
            public var cachePolicy: URLRequest.CachePolicy
            
            /// Default headers to include in all requests
            public var defaultHeaders: [String: String]
            
            /// Creates a new network configuration
            public init(
                apiKey: String,
                timeoutInterval: TimeInterval = 30.0,
                cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                defaultHeaders: [String: String] = [:]
            ) {
                self.apiKey = apiKey
                self.timeoutInterval = timeoutInterval
                self.cachePolicy = cachePolicy
                self.defaultHeaders = defaultHeaders
            }
            
            /// Creates a session configuration from this network configuration
            public func makeSessionConfiguration() -> URLSessionConfiguration {
                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForRequest = timeoutInterval
                configuration.requestCachePolicy = cachePolicy
                
                var headers = defaultHeaders
                headers["Authorization"] = "Bearer \\(apiKey)"
                
                configuration.httpAdditionalHeaders = headers
                return configuration
            }
            
            /// Default configuration for development environment
            public static let development = NetworkConfiguration(
                apiKey: "dev_api_key",
                timeoutInterval: 60.0,
                defaultHeaders: ["X-Environment": "development"]
            )
            
            /// Default configuration for production environment
            public static let production: NetworkConfiguration = NetworkConfiguration(
                apiKey: "prod_api_key",
                timeoutInterval: 30.0,
                defaultHeaders: ["X-Environment": "production"]
            )
            
            /// Compares two network configurations for equality
            public static func == (lhs: NetworkConfiguration, rhs: NetworkConfiguration) -> Bool {
                return lhs.apiKey == rhs.apiKey &&
                       lhs.timeoutInterval == rhs.timeoutInterval &&
                       lhs.cachePolicy == rhs.cachePolicy &&
                       lhs.defaultHeaders == rhs.defaultHeaders
            }
        }
        """
        
        try structContent.write(toFile: testFilesDirectory + "/NetworkConfiguration.swift", atomically: true, encoding: .utf8)
    }
    
    private func createProtocolFile() throws {
        let protocolContent = """
        import Foundation
        
        /// Protocol for network service providers
        public protocol NetworkServiceProvider {
            /// Base URL for the service
            var baseURL: URL { get }
            
            /// Session used for network requests
            var session: URLSession { get }
            
            /// Fetches data from the specified endpoint
            /// - Parameters:
            ///   - endpoint: API endpoint to fetch
            ///   - completion: Completion handler
            func fetchData(from endpoint: String, completion: @escaping (Result<Data, Error>) -> Void)
            
            /// Performs a GET request
            func get(from endpoint: String) async throws -> Data
            
            /// Performs a POST request
            func post(to endpoint: String, body: Data) async throws -> Data
            
            /// Cancels all ongoing requests
            func cancelAllRequests()
        }
        
        /// Protocol for handling request authentication
        public protocol RequestAuthenticator {
            /// Authenticates a request
            /// - Parameter request: The request to authenticate
            /// - Returns: An authenticated request
            func authenticate(request: URLRequest) -> URLRequest
            
            /// Refreshes authentication credentials
            /// - Returns: A boolean indicating success
            func refreshCredentials() async throws -> Bool
        }
        
        /// Protocol for configurable services
        public protocol Configurable {
            /// Associated type for configuration
            associatedtype Configuration
            
            /// Configures the service
            /// - Parameter configuration: The configuration to apply
            func configure(with configuration: Configuration)
        }
        """
        
        try protocolContent.write(toFile: testFilesDirectory + "/NetworkProtocols.swift", atomically: true, encoding: .utf8)
    }
    
    // MARK: - Declaration API Tests

    func testImportDeclaration() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let imports = scope.imports()
            .filter { $0.isImportOf("Foundation") }

        XCTAssertEqual(scope.files().count, 3, "Should have 3 files")
        XCTAssertEqual(imports.count, 3, "Each file should import Foundation")
    }

    func testClassDeclaration() {
        // Get the class declaration
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let classes = scope.classes()
        
        XCTAssertEqual(classes.count, 1, "Should find 1 class")
        
        guard let networkService = classes.first else {
            XCTFail("NetworkService class not found")
            return
        }
        
        // Test basic properties
        XCTAssertEqual(networkService.name, "NetworkService", "Class name should be NetworkService")
        XCTAssertTrue(networkService.hasModifier(.public), "NetworkService should be public")
        XCTAssertTrue(networkService.hasModifier(.final), "NetworkService should be final")
        
        // Test annotations
        XCTAssertTrue(networkService.hasAnnotation(named: "available"), "NetworkService should have @available annotation")
        
        // Test properties
        XCTAssertTrue(networkService.hasProperty(named: "baseURL"), "NetworkService should have baseURL property")
        XCTAssertTrue(networkService.hasProperty(named: "session"), "NetworkService should have session property")
        XCTAssertTrue(networkService.hasProperty(named: "isActive"), "NetworkService should have isActive property")
        XCTAssertTrue(networkService.hasProperty(named: "shared"), "NetworkService should have shared property")
        
        // Test methods
        XCTAssertTrue(networkService.hasMethod(named: "init"), "NetworkService should have init method")
        XCTAssertTrue(networkService.hasMethod(named: "fetchData"), "NetworkService should have fetchData method")
        XCTAssertTrue(networkService.hasMethod(named: "cancelAllRequests"), "NetworkService should have cancelAllRequests method")
        XCTAssertTrue(networkService.hasMethod(named: "configure"), "NetworkService should have configure method")
        
        // Test method count
        let methods = networkService.methods
        XCTAssertEqual(methods.count, 4, "NetworkService should have 4 methods in the class declaration")
        
        // Get the extension methods
        let extensions = scope.extensions().filter { $0.name == "NetworkService" }
        XCTAssertEqual(extensions.count, 1, "Should find 1 extension for NetworkService")
        
        if let extension1 = extensions.first {
            let extensionMethods = extension1.methods
            XCTAssertEqual(extensionMethods.count, 2, "NetworkService extension should have 2 methods")
            XCTAssertTrue(extensionMethods.contains { $0.name == "get" }, "Extension should have get method")
            XCTAssertTrue(extensionMethods.contains { $0.name == "post" }, "Extension should have post method")
        }
    }
    
    func testStructDeclaration() {
        // Get the struct declaration
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let structs = scope.structs()
        
        XCTAssertEqual(structs.count, 1, "Should find 1 struct")
        
        guard let networkConfig = structs.first else {
            XCTFail("NetworkConfiguration struct not found")
            return
        }
        
        // Test basic properties
        XCTAssertEqual(networkConfig.name, "NetworkConfiguration", "Struct name should be NetworkConfiguration")
        XCTAssertTrue(networkConfig.hasModifier(.public), "NetworkConfiguration should be public")
        
        // Test protocols
        XCTAssertTrue(networkConfig.implements(protocol: "Codable"), "NetworkConfiguration should implement Codable")
        XCTAssertTrue(networkConfig.implements(protocol: "Equatable"), "NetworkConfiguration should implement Equatable")
        
        // Test properties
        XCTAssertTrue(networkConfig.hasProperty(named: "apiKey"), "NetworkConfiguration should have apiKey property")
        XCTAssertTrue(networkConfig.hasProperty(named: "timeoutInterval"), "NetworkConfiguration should have timeoutInterval property")
        XCTAssertTrue(networkConfig.hasProperty(named: "cachePolicy"), "NetworkConfiguration should have cachePolicy property")
        XCTAssertTrue(networkConfig.hasProperty(named: "defaultHeaders"), "NetworkConfiguration should have defaultHeaders property")
        XCTAssertTrue(networkConfig.hasProperty(named: "development"), "NetworkConfiguration should have development static property")
        XCTAssertTrue(networkConfig.hasProperty(named: "production"), "NetworkConfiguration should have production static property")
        
        // Test methods
        XCTAssertTrue(networkConfig.hasMethod(named: "init"), "NetworkConfiguration should have init method")
        XCTAssertTrue(networkConfig.hasMethod(named: "makeSessionConfiguration"), "NetworkConfiguration should have makeSessionConfiguration method")
        XCTAssertTrue(networkConfig.hasMethod(named: "=="), "NetworkConfiguration should have == method")
        
        // Test property count
        let properties = networkConfig.properties
        XCTAssertEqual(properties.count, 6, "NetworkConfiguration should have 6 properties")
        
        // Test static properties
        let staticProperties = properties.filter { $0.hasModifier(.static) }
        XCTAssertEqual(staticProperties.count, 2, "NetworkConfiguration should have 2 static properties")
    }
    
    func testProtocolDeclaration() {
        // Get the protocol declarations
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let protocols = scope.protocols()
        
        XCTAssertEqual(protocols.count, 3, "Should find 3 protocols")
        
        // Test NetworkServiceProvider protocol
        guard let serviceProvider = protocols.first(where: { $0.name == "NetworkServiceProvider" }) else {
            XCTFail("NetworkServiceProvider protocol not found")
            return
        }
        
        XCTAssertEqual(serviceProvider.name, "NetworkServiceProvider", "Protocol name should be NetworkServiceProvider")
        XCTAssertTrue(serviceProvider.hasModifier(.public), "NetworkServiceProvider should be public")
        
        let propertyRequirements = serviceProvider.propertyRequirements
        XCTAssertEqual(propertyRequirements.count, 2, "NetworkServiceProvider should have 2 property requirements")
        XCTAssertTrue(propertyRequirements.contains { $0.name == "baseURL" }, "Should have baseURL property requirement")
        XCTAssertTrue(propertyRequirements.contains { $0.name == "session" }, "Should have session property requirement")
        
        let methodRequirements = serviceProvider.methodRequirements
        XCTAssertEqual(methodRequirements.count, 4, "NetworkServiceProvider should have 4 method requirements")
        XCTAssertTrue(methodRequirements.contains { $0.name == "fetchData" }, "Should have fetchData method requirement")
        XCTAssertTrue(methodRequirements.contains { $0.name == "get" }, "Should have get method requirement")
        XCTAssertTrue(methodRequirements.contains { $0.name == "post" }, "Should have post method requirement")
        XCTAssertTrue(methodRequirements.contains { $0.name == "cancelAllRequests" }, "Should have cancelAllRequests method requirement")
        
        guard let configurable = protocols.first(where: { $0.name == "Configurable" }) else {
            XCTFail("Configurable protocol not found")
            return
        }
        
        let configurableMethods = configurable.methodRequirements
        XCTAssertEqual(configurableMethods.count, 1, "Configurable should have 1 method requirement")
        XCTAssertTrue(configurableMethods.contains { $0.name == "configure" }, "Should have configure method requirement")
    }
    
    func testExtensionDeclaration() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let extensions = scope.extensions()
        
        XCTAssertEqual(extensions.count, 1, "Should find 1 extension")
        
        guard let networkServiceExt = extensions.first else {
            XCTFail("NetworkService extension not found")
            return
        }
        
        XCTAssertEqual(networkServiceExt.name, "NetworkService", "Extension name should be NetworkService")
        
        let methods = networkServiceExt.methods
        XCTAssertEqual(methods.count, 2, "Extension should have 2 methods")
        XCTAssertTrue(methods.contains { $0.name == "get" }, "Extension should have get method")
        XCTAssertTrue(methods.contains { $0.name == "post" }, "Extension should have post method")
        
        if let getMethod = methods.first(where: { $0.name == "get" }) {
            XCTAssertTrue(getMethod.hasModifier(.public), "get method should be public")
            XCTAssertEqual(getMethod.parameters.count, 1, "get method should have 1 parameter")
            XCTAssertEqual(getMethod.parameters.first?.name, "endpoint", "get method should have endpoint parameter")
            XCTAssertEqual(getMethod.returnType, "Data", "get method should return Data")
        }
        
        if let postMethod = methods.first(where: { $0.name == "post" }) {
            XCTAssertTrue(postMethod.hasModifier(.public), "post method should be public")
            XCTAssertEqual(postMethod.parameters.count, 2, "post method should have 2 parameters")
            XCTAssertEqual(postMethod.parameters.first?.name, "endpoint", "post method should have endpoint parameter")
            XCTAssertEqual(postMethod.parameters.last?.name, "body", "post method should have body parameter")
            XCTAssertEqual(postMethod.returnType, "Data", "post method should return Data")
        }
    }
    
    func testMethodDeclaration() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let classes = scope.classes()
        
        guard let networkService = classes.first(where: { $0.name == "NetworkService" }) else {
            XCTFail("NetworkService class not found")
            return
        }
        
        guard let initMethod = networkService.methods.first(where: { $0.name == "init" }) else {
            XCTFail("init method not found")
            return
        }
        
        XCTAssertEqual(initMethod.name, "init", "Method name should be init")
        XCTAssertTrue(initMethod.hasModifier(.public), "init method should be public")
        XCTAssertFalse(initMethod.hasReturnType(), "init method should not have a return type")
        
        XCTAssertEqual(initMethod.parameters.count, 2, "init method should have 2 parameters")
        
        let baseURLParam = initMethod.parameters.first(where: { $0.name == "baseURL" })
        XCTAssertNotNil(baseURLParam, "Should have baseURL parameter")
        XCTAssertEqual(baseURLParam?.type, "URL", "baseURL parameter should be of type URL")
        XCTAssertNil(baseURLParam?.defaultValue, "baseURL parameter should not have a default value")
        
        let sessionParam = initMethod.parameters.first(where: { $0.name == "session" })
        XCTAssertNotNil(sessionParam, "Should have session parameter")
        XCTAssertEqual(sessionParam?.type, "URLSession", "session parameter should be of type URLSession")
        XCTAssertEqual(sessionParam?.defaultValue, ".shared", "session parameter should have .shared default value")
        
        guard let fetchDataMethod = networkService.methods.first(where: { $0.name == "fetchData" }) else {
            XCTFail("fetchData method not found")
            return
        }
        
        XCTAssertEqual(fetchDataMethod.name, "fetchData", "Method name should be fetchData")
        XCTAssertTrue(fetchDataMethod.hasModifier(.public), "fetchData method should be public")
        XCTAssertFalse(fetchDataMethod.hasReturnType(), "fetchData method should not have a return type")
        
        XCTAssertEqual(fetchDataMethod.parameters.count, 2, "fetchData method should have 2 parameters")
        
        let endpointParam = fetchDataMethod.parameters.first(where: { $0.name == "endpoint" })
        XCTAssertNotNil(endpointParam, "Should have from parameter")
        
        let completionParam = fetchDataMethod.parameters.first(where: { $0.name == "completion" })
        XCTAssertNotNil(completionParam, "Should have completion parameter")
        XCTAssertTrue(completionParam?.type.contains("@escaping") ?? false, "completion parameter should be @escaping")
    }
    
    func testPropertyDeclaration() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let structs = scope.structs()
        
        guard let networkConfig = structs.first(where: { $0.name == "NetworkConfiguration" }) else {
            XCTFail("NetworkConfiguration struct not found")
            return
        }
        
        // Test apiKey property
        guard let apiKeyProp = networkConfig.properties.first(where: { $0.name == "apiKey" }) else {
            XCTFail("apiKey property not found")
            return
        }
        
        XCTAssertEqual(apiKeyProp.name, "apiKey", "Property name should be apiKey")
        XCTAssertTrue(apiKeyProp.hasModifier(.public), "apiKey property should be public")
        XCTAssertEqual(apiKeyProp.type, "String", "apiKey property should be of type String")
        XCTAssertFalse(apiKeyProp.isComputed, "apiKey property should not be computed")
        XCTAssertNil(apiKeyProp.initialValue, "apiKey property should not have an initial value")
        
        // Test timeoutInterval property
        guard let timeoutProp = networkConfig.properties.first(where: { $0.name == "timeoutInterval" }) else {
            XCTFail("timeoutInterval property not found")
            return
        }
        
        XCTAssertEqual(timeoutProp.name, "timeoutInterval", "Property name should be timeoutInterval")
        XCTAssertTrue(timeoutProp.hasModifier(.public), "timeoutInterval property should be public")
        XCTAssertEqual(timeoutProp.type, "TimeInterval", "timeoutInterval property should be of type TimeInterval")
        XCTAssertFalse(timeoutProp.isComputed, "timeoutInterval property should not be computed")
        XCTAssertNil(timeoutProp.initialValue, "timeoutInterval property should not have an initial value in the declaration")
        
        // Test development static property
        guard let devProp = networkConfig.properties.first(where: { $0.name == "development" }) else {
            XCTFail("development property not found")
            return
        }
        
        XCTAssertEqual(devProp.name, "development", "Property name should be development")
        XCTAssertTrue(devProp.hasModifier(.public), "development property should be public")
        XCTAssertTrue(devProp.hasModifier(.static), "development property should be static")
        XCTAssertEqual(devProp.type, "NetworkConfiguration", "production property should be of type NetworkConfiguration")
        XCTAssertFalse(devProp.isComputed, "development property should not be computed")
        XCTAssertNotNil(devProp.initialValue, "development property should have an initial value")

        // Test production static property
        guard let devProp = networkConfig.properties.first(where: { $0.name == "production" }) else {
            XCTFail("production property not found")
            return
        }

        XCTAssertEqual(devProp.name, "production", "Property name should be production")
        XCTAssertTrue(devProp.hasModifier(.public), "production property should be public")
        XCTAssertTrue(devProp.hasModifier(.static), "production property should be static")
        XCTAssertEqual(devProp.type, "NetworkConfiguration", "production property should be of type NetworkConfiguration")
        XCTAssertFalse(devProp.isComputed, "production property should not be computed")
        XCTAssertNotNil(devProp.initialValue, "production property should have an initial value")
    }
    
    func testModifiersAndAnnotations() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let classes = scope.classes()
        
        guard let networkService = classes.first(where: { $0.name == "NetworkService" }) else {
            XCTFail("NetworkService class not found")
            return
        }
        
        // Test modifiers
        XCTAssertTrue(networkService.hasModifier(.public), "NetworkService should be public")
        XCTAssertTrue(networkService.hasModifier(.final), "NetworkService should be final")
        XCTAssertFalse(networkService.hasModifier(.static), "NetworkService should not be static")
        XCTAssertFalse(networkService.hasModifier(.private), "NetworkService should not be private")
        
        // Test annotations
        XCTAssertTrue(networkService.hasAnnotation(named: "available"), "NetworkService should have @available annotation")
        XCTAssertFalse(networkService.hasAnnotation(named: "objc"), "NetworkService should not have @objc annotation")
        
        // Test annotation arguments
        let availableAnnotation = networkService.annotations.first(where: { $0.name == "available" })
        XCTAssertNotNil(availableAnnotation, "Should find available annotation")
        XCTAssertTrue(availableAnnotation?.arguments.keys.contains("iOS") ?? false, "Annotation should have iOS argument")
        XCTAssertEqual(availableAnnotation?.arguments["iOS"], "13.0", "iOS argument should be 13.0")
        
        // Test method annotations
        guard let cancelMethod = networkService.methods.first(where: { $0.name == "cancelAllRequests" }) else {
            XCTFail("cancelAllRequests method not found")
            return
        }
        
        XCTAssertTrue(cancelMethod.hasAnnotation(named: "available"), "cancelAllRequests method should have @available annotation")
        let methodAnnotation = cancelMethod.annotations.first(where: { $0.name == "available" })
        XCTAssertNotNil(methodAnnotation, "Should find available annotation")
        XCTAssertTrue(methodAnnotation?.arguments.keys.contains("iOS") ?? false, "Annotation should have iOS argument")
        XCTAssertEqual(methodAnnotation?.arguments["iOS"], "14.0", "iOS argument should be 14.0")
    }
    
    func testResideInPackage() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let allDeclarations = scope.declarations()

        for declaration in allDeclarations {
            XCTAssertTrue(declaration.resideInPackage(testFilesDirectory), "Declaration should reside in test directory")
        }
        
        let networkRelated = allDeclarations.filter { $0.resideInPackage(".*Network.*") }
        XCTAssertEqual(networkRelated.count, allDeclarations.count, "All declarations should match '.*Network.*' pattern")
        
        let serviceFile = allDeclarations.filter { $0.resideInPackage(".*NetworkService\\.swift") }
        XCTAssertEqual(serviceFile.count, 2, "Should find 2 declarations in NetworkService.swift") // Class + Extension

        let configFile = allDeclarations.filter { $0.resideInPackage("..NetworkConfiguration..") }
        XCTAssertEqual(configFile.count, 1, "Should find 1 declaration in NetworkConfiguration.swift")
    }
    
    func testLocation() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let allDeclarations = scope.declarations()

        for declaration in allDeclarations {
            XCTAssertEqual(declaration.location.file, declaration.filePath, "Location file should match containing file path")
            XCTAssertGreaterThanOrEqual(declaration.location.line, 1, "Line should be 1")
            XCTAssertGreaterThanOrEqual(declaration.location.column, 1, "Column should be 1")
        }
    }
}
