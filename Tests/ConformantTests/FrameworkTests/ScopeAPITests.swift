import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class ScopeAPITests: XCTestCase {
    func testFromDirectory() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        XCTAssertEqual(scope.files().count, 6, "Should find all 6 Swift files in the directory")
    }

    func testFromFile() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let filePath = testFilesDirectory + "/TestClass.swift"
        let scope = Conformant.scopeFromFile(path: filePath)

        XCTAssertEqual(scope.files().count, 1, "Should contain only one file")
        XCTAssertEqual(scope.files().first?.path, filePath, "Should match the requested file path")
    }

    func testClassesRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let classes = scope.classes()

        XCTAssertEqual(classes.count, 3, "Should find 3 classes (TestClass, TestSubclass, NetworkMonitor)")

        let classNames = classes.map { $0.name }
        XCTAssertTrue(classNames.contains("TestClass"), "Should find TestClass")
        XCTAssertTrue(classNames.contains("TestSubclass"), "Should find TestSubclass")
        XCTAssertTrue(classNames.contains("NetworkMonitor"), "Should find NetworkMonitor")

        let publicClasses = classes.filter { $0.hasModifier(.public) }
        XCTAssertEqual(publicClasses.count, 2, "Should find 2 public classes")

        let finalClasses = classes.filter { $0.hasModifier(.final) }
        XCTAssertEqual(finalClasses.count, 1, "Should find 1 final class")

        if let testClass = classes.first(where: { $0.name == "TestClass"}) {
            XCTAssertGreaterThan(testClass.location.line, 0, "TestClass location line should be greater than 0")
        } else {
            XCTFail("TestClass not found")
        }
    }

    func testStructsRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let structs = scope.structs()

        XCTAssertEqual(structs.count, 2, "Should find 2 structs (User, Configuration)")

        let structNames = structs.map { $0.name }
        XCTAssertTrue(structNames.contains("User"), "Should find User struct")
        XCTAssertTrue(structNames.contains("Configuration"), "Should find Configuration struct")

        if let userStruct = structs.first(where: { $0.name == "User" }) {
            // Properties: id, firstName, lastName, email, fullName (computed)
            // Check for non-computed properties first
            let storedProperties = userStruct.properties.filter { !$0.isComputed }
            XCTAssertEqual(storedProperties.count, 4, "User struct should have 4 stored properties")
            let computedProperties = userStruct.properties.filter { $0.isComputed }
            XCTAssertEqual(computedProperties.count, 1, "User struct should have 1 computed property (fullName)")

            // Check for implementing protocols (Codable might be inferred, check explicit ones)
            XCTAssertTrue(userStruct.implements(protocol: "Codable"), "User should implement Codable")
            XCTAssertTrue(userStruct.implements(protocol: "Equatable"), "User should implement Equatable")
            XCTAssertTrue(userStruct.implements(protocol: "Identifiable"), "User should implement Identifiable")
        } else {
            XCTFail("Could not find User struct")
        }
    }


    func testProtocolsRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let protocols = scope.protocols()

        XCTAssertEqual(protocols.count, 5, "Should find 5 protocols (Repository, UserManagement, Observable, Observer, NetworkMonitoring)")

        let protocolNames = protocols.map { $0.name }
        XCTAssertTrue(protocolNames.contains("Repository"), "Should find Repository protocol")
        XCTAssertTrue(protocolNames.contains("UserManagement"), "Should find UserManagement protocol")
        XCTAssertTrue(protocolNames.contains("Observable"), "Should find Observable protocol")
        XCTAssertTrue(protocolNames.contains("Observer"), "Should find Observer protocol") // Note the <Event> might be part of the name depending on parsing detail
        XCTAssertTrue(protocolNames.contains("NetworkMonitoring"), "Should find NetworkMonitoring protocol")

        // Validation of protocol requirements
        if let repository = protocols.first(where: { $0.name == "Repository" }) {
            XCTAssertEqual(repository.methodRequirements.count, 4, "Repository should have 4 method requirements")
            let methodNames = repository.methodRequirements.map { $0.name }
            XCTAssertTrue(methodNames.contains("fetch"), "Should find fetch method")
            XCTAssertTrue(methodNames.contains("save"), "Should find save method")
            XCTAssertTrue(methodNames.contains("delete"), "Should find delete method")
            XCTAssertTrue(methodNames.contains("listAll"), "Should find listAll method")

            // Check for property requirements (associatedtype isn't captured as SwiftPropertyDeclaration currently)
            XCTAssertEqual(repository.propertyRequirements.count, 0, "Repository should have 0 property requirements (associatedtypes not captured as properties)")
        } else {
            XCTFail("Could not find Repository protocol")
        }

        // Check Observer protocol name detail
        XCTAssertTrue(protocols.contains { $0.name == "Observer" }, "Should find Observer protocol")
    }

    func testExtensionsRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let extensions = scope.extensions()

        // Extension count validation: User, User+CustomStringConvertible, String, NetworkMonitor+NetworkMonitoring
        XCTAssertEqual(extensions.count, 4, "Should find 4 extensions")

        let extensionTypes = extensions.map { $0.name }
        XCTAssertEqual(extensionTypes.filter { $0 == "User" }.count, 2, "Should find 2 extensions for User")
        XCTAssertTrue(extensionTypes.contains("String"), "Should find String extension")
        XCTAssertTrue(extensionTypes.contains("NetworkMonitor"), "Should find NetworkMonitor extension")

        let userExtensions = extensions.filter { $0.name == "User" }

        // Find the extension that adds CustomStringConvertible
        let customStringExt = userExtensions.first { $0.implements(protocol: "CustomStringConvertible") }
        XCTAssertNotNil(customStringExt, "Should find User extension conforming to CustomStringConvertible")
        XCTAssertEqual(customStringExt?.methods.count ?? -1, 0, "User+CustomStringConvertible extension should have 0 methods (only property 'description')")
        XCTAssertEqual(customStringExt?.properties.count ?? -1, 1, "User+CustomStringConvertible extension should have 1 property ('description')")
        XCTAssertTrue(customStringExt?.properties.first?.name == "description", "User+CustomStringConvertible extension should have 'description' property")

        // Find the other User extension
        let otherUserExt = userExtensions.first { !$0.implements(protocol: "CustomStringConvertible") }
        XCTAssertNotNil(otherUserExt, "Should find the other User extension")
        XCTAssertEqual(otherUserExt?.methods.count ?? -1, 2, "Other User extension should have 2 methods")
        XCTAssertTrue(otherUserExt?.methods.contains { $0.name == "formatted" } ?? false, "Should find formatted method")
        XCTAssertTrue(otherUserExt?.methods.contains { $0.name == "createWithFullName" } ?? false, "Should find createWithFullName method")
        XCTAssertEqual(otherUserExt?.properties.count ?? -1, 0, "Other User extension should have 0 properties")

        if let stringExt = extensions.first(where: { $0.name == "String" }) {
            XCTAssertEqual(stringExt.properties.count, 1, "String extension should have 1 property (isValidEmail)")
            XCTAssertEqual(stringExt.methods.count, 1, "String extension should have 1 method (truncated)")
            XCTAssertTrue(stringExt.properties.first?.name == "isValidEmail", "String extension should have 'isValidEmail' property")
            XCTAssertTrue(stringExt.methods.first?.name == "truncated", "String extension should have 'truncated' method")
        } else {
            XCTFail("Could not find String extension")
        }
    }

    func testEnumsRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let enums = scope.enums()

        XCTAssertEqual(enums.count, 3, "Should find 3 enums (UserRole, APIError, ConnectionType)")

        let enumNames = enums.map { $0.name }
        XCTAssertTrue(enumNames.contains("UserRole"), "Should find UserRole enum")
        XCTAssertTrue(enumNames.contains("APIError"), "Should find APIError enum")
        XCTAssertTrue(enumNames.contains("ConnectionType"), "Should find ConnectionType enum")

        if let userRole = enums.first(where: { $0.name == "UserRole" }) {
            XCTAssertEqual(userRole.cases.count, 4, "UserRole should have 4 cases")
            XCTAssertEqual(userRole.rawType, "String", "UserRole raw type should be String")
            XCTAssertTrue(userRole.implements(protocol: "Codable"), "UserRole should implement Codable")

            let caseNames = userRole.cases.map { $0.name }
            XCTAssertTrue(caseNames.contains("admin"), "Should find admin case")

            XCTAssertEqual(userRole.properties.count, 2, "UserRole should have 2 computed properties")
            XCTAssertTrue(userRole.properties.contains { $0.name == "canModifyContent" && $0.isComputed }, "Should find computed property canModifyContent")
            XCTAssertTrue(userRole.properties.contains { $0.name == "displayName" && $0.isComputed }, "Should find computed property displayName")
            XCTAssertEqual(userRole.methods.count, 0, "UserRole should have 0 methods")
        } else {
            XCTFail("Could not find UserRole enum")
        }

        if let apiError = enums.first(where: { $0.name == "APIError" }) {
            XCTAssertEqual(apiError.cases.count, 6, "APIError should have 6 cases")
            XCTAssertNil(apiError.rawType, "APIError should not have a raw type")
            XCTAssertTrue(apiError.implements(protocol: "Error"), "APIError should implement Error")

            let networkErrorCase = apiError.cases.first { $0.name == "networkError" }
            XCTAssertNotNil(networkErrorCase)
            XCTAssertEqual(networkErrorCase?.associatedValues, ["String"])

            XCTAssertEqual(apiError.properties.count, 1, "APIError should have 1 computed property (description)")
            XCTAssertTrue(apiError.properties.first?.name == "description" && apiError.properties.first?.isComputed == true)
        } else {
            XCTFail("Could not find APIError enum")
        }
    }

    func testTopLevelFunctionsRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let functions = scope.functions()

        XCTAssertEqual(functions.count, 1, "Should find 1 top-level function")

        let function = functions.first
        XCTAssertEqual(function?.name, "formatCurrency", "Should find formatCurrency function")

        if let formatFunction = function {
            XCTAssertEqual(formatFunction.parameters.count, 2, "Should have 2 parameters")
            let parameterNames = formatFunction.parameters.map { $0.name }
            XCTAssertTrue(parameterNames.contains("amount"), "Should have amount parameter")
            XCTAssertTrue(parameterNames.contains("currencyCode"), "Should have currencyCode parameter")
            XCTAssertEqual(formatFunction.parameters.first { $0.name == "currencyCode" }?.defaultValue, "\"USD\"", "currencyCode should have default value")
            XCTAssertEqual(formatFunction.returnType, "String", "Should return String")

            XCTAssertGreaterThan(formatFunction.location.line, 0, "formatCurrency location line should be > 0")
        } else {
            XCTFail("Could not find formatCurrency function")
        }
    }

    func testTopLevelPropertiesRetrieval() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let properties = scope.properties()

        XCTAssertEqual(properties.count, 1, "Should find 1 top-level property")

        if let apiVersionProp = properties.first {
            XCTAssertEqual(apiVersionProp.name, "apiVersion", "Should find apiVersion property")
            // Type inference might not work perfectly, explicit type is best
            // Let's check the parsed type (might be Any if not annotated, check Mixed.swift)
            // Mixed.swift has `public let apiVersion = "1.0.0"` - no explicit type.
            // Parser currently defaults to "Any" if no type annotation. Update if type inference added.
            XCTAssertEqual(apiVersionProp.type, "Any", "Should default to Any if no type annotation")
            XCTAssertEqual(apiVersionProp.initialValue, "\"1.0.0\"", "Should have correct initial value")
            XCTAssertFalse(apiVersionProp.isComputed, "apiVersion should not be computed")

            XCTAssertGreaterThan(apiVersionProp.location.line, 0, "apiVersion location line should be > 0")
        } else {
            XCTFail("Could not find apiVersion property")
        }
    }

    func testFilteringByName() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let testClasses = scope.classes().withNameStarting(with: "Test")
        XCTAssertEqual(testClasses.count, 2, "Should find 2 classes with 'Test' prefix")

        let configStructs = scope.structs().withNameEnding(with: "Configuration")
        XCTAssertEqual(configStructs.count, 1, "Should find 1 struct with 'Configuration' suffix")

        let userTypes = scope.types().withName(containing: "User")
        XCTAssertEqual(userTypes.count, 3, "Should find 3 types containing 'User'")

        // Filter types by regex
        let errorTypes = scope.declarations().withNameMatching(".*Error")
        // APIError (enum) = 1
        XCTAssertEqual(errorTypes.count, 1, "Should find 1 type matching '.*Error'")
    }

    func testFilteringByModifiers() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let publicTypes = scope.types().filter { $0.hasModifier(.public) }
        // TestClass, User, Repository, UserManagement, Observable, Observer, UserRole, APIError, Configuration, NetworkMonitor, ConnectionType, NetworkMonitoring = 12
        XCTAssertEqual(publicTypes.count, 12, "Should find 12 public types (class, struct, enum, protocol)")

        let finalClasses = scope.classes().filter { $0.hasModifier(.final) }
        // TestClass = 1
        XCTAssertEqual(finalClasses.count, 1, "Should find 1 final class")

        let allClasses = scope.classes()
        let allStructs = scope.structs()
        let allEnums = scope.enums()
        let allExtensions = scope.extensions()

        let allMethods = allClasses.flatMap { $0.methods } +
        allStructs.flatMap { $0.methods } +
        allEnums.flatMap { $0.methods } +
        allExtensions.flatMap { $0.methods }

        let staticMethods = allMethods.filter { $0.hasModifier(.static) }
        XCTAssertEqual(staticMethods.count, 2, "Should find 2 static methods")

        var allProperties: [SwiftPropertyDeclaration] = []
        allProperties.append(contentsOf: allClasses.flatMap({ $0.properties }))
        allProperties.append(contentsOf: allStructs.flatMap({ $0.properties }))
        allProperties.append(contentsOf: allEnums.flatMap({ $0.properties }))
        allProperties.append(contentsOf: allExtensions.flatMap({ $0.properties }))
        allProperties.append(contentsOf: scope.properties())

        let staticProperties = allProperties.filter { $0.hasModifier(.static) }
        // TestClass.shared, NetworkMonitor.shared = 2
        XCTAssertEqual(staticProperties.count, 2, "Should find 2 static properties")
    }

    func testAssertions() throws {
        let testFilesDirectory = try makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }
        
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let publicClasses = scope.classes().filter { $0.hasModifier(.public) }
        let initResult = publicClasses.assertTrue { publicClass in
            let initializers = publicClass.methods.filter { $0.name == "init" }
            if initializers.isEmpty {
                // No explicit init - technically okay for classes with no stored properties needing init,
                // but TestClass requires init. NetworkMonitor *has* an init.
                // Let's assume for this rule, if a public class exists, it needs a *defined* public init if any init is defined.
                print("  - WARNING: \(publicClass.name) has no explicit initializers.")
                // Depending on strictness, this could be true or false.
                // Let's check if it *needs* an init based on properties (simplistic check)
                let needsInit = !publicClass.properties.filter { !$0.isComputed && $0.initialValue == nil }.isEmpty
                return !needsInit // Passes if it doesn't seem to need an explicit init
            } else {
                // Check if AT LEAST ONE initializer is public
                let hasPublicInit = initializers.contains { $0.hasModifier(.public) }
                print("  - \(publicClass.name): Has explicit inits. Has public init? \(hasPublicInit)")
                return hasPublicInit
            }
        }

        XCTAssertFalse(initResult, "Assertion should fail because NetworkMonitor lacks a public initializer.")

        // Test that all error types (enums containing 'Error' in name) implement Error protocol
        // Note: This relies on naming convention, not ideal but okay for this test structure.
        let errorTypes = scope.enums().filter { $0.name.contains("Error") }
        let errorResult = errorTypes.assertTrue { errorType in
            // Check implements protocol (note: needs refinement if protocol has generic constraints)
            return errorType.implements(protocol: "Error")
        }
        XCTAssertTrue(errorResult, "All types named '*Error' should implement Error protocol (APIError)")
    }
}

extension ScopeAPITests {
    func makeSUT() throws -> String {
        let testFilesDirectory = NSTemporaryDirectory() + "ScopeAPITests_" + UUID().uuidString

        try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)

        try createClassFile(testFilesDirectory)
        try createStructFile(testFilesDirectory)
        try createProtocolFile(testFilesDirectory)
        try createExtensionFile(testFilesDirectory)
        try createEnumFile(testFilesDirectory)
        try createMixedFile(testFilesDirectory)

        return testFilesDirectory
    }

    func cleanup(_ testFilesDirectory: String) {
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }

    private func createClassFile(_ testFilesDirectory: String) throws {
        let classContent = """
        import Foundation
        
        /// A test class with various features
        public final class TestClass {
            // Properties
            private let id: String
            public var name: String
            static let shared = TestClass(id: "singleton", name: "Shared Instance")
            
            // Initializer
            public init(id: String, name: String) {
                self.id = id
                self.name = name
            }
            
            // Methods
            public func doSomething() -> Bool {
                print("Doing something with \\(name)")
                return true
            }
            
            private func privateHelper() {
                print("Private helper called")
            }
        }
        
        // Subclass
        class TestSubclass: TestClass {
            var additionalProperty: Int
            
            public init(id: String, name: String, additionalProperty: Int) {
                self.additionalProperty = additionalProperty
                super.init(id: id, name: name)
            }
            
            override func doSomething() -> Bool {
                print("Overridden in subclass")
                return false
            }
        }
        """

        try classContent.write(toFile: testFilesDirectory + "/TestClass.swift", atomically: true, encoding: .utf8)
    }

    private func createStructFile(_ testFilesDirectory: String) throws {
        let structContent = """
        import Foundation
        
        /// A test struct representing a user
        public struct User: Codable, Equatable, Identifiable {
            // Properties
            public let id: UUID
            public var firstName: String
            public var lastName: String
            public var email: String?
            
            // Computed property
            public var fullName: String {
                return "\\(firstName) \\(lastName)"
            }
            
            // Initializer
            public init(id: UUID = UUID(), firstName: String, lastName: String, email: String? = nil) {
                self.id = id
                self.firstName = firstName
                self.lastName = lastName
                self.email = email
            }
            
            // Methods
            public func toJSON() -> [String: Any] {
                var json: [String: Any] = [
                    "id": id.uuidString,
                    "firstName": firstName,
                    "lastName": lastName
                ]
                
                if let email = email {
                    json["email"] = email
                }
                
                return json
            }
            
            // Static function
            public static func == (lhs: User, rhs: User) -> Bool {
                return lhs.id == rhs.id
            }
        }
        """

        try structContent.write(toFile: testFilesDirectory + "/User.swift", atomically: true, encoding: .utf8)
    }

    private func createProtocolFile(_ testFilesDirectory: String) throws {
        let protocolContent = """
        import Foundation
        
        /// A protocol for repository access
        public protocol Repository {
            associatedtype Entity
            associatedtype ID
            
            /// Fetches an entity by its ID
            func fetch(id: ID) async throws -> Entity
            
            /// Saves an entity
            func save(_ entity: Entity) async throws
            
            /// Deletes an entity
            func delete(id: ID) async throws
            
            /// Lists all entities
            func listAll() async throws -> [Entity]
        }
        
        /// A protocol for user management
        public protocol UserManagement {
            /// Authenticates a user
            func authenticate(email: String, password: String) async throws -> User
            
            /// Logs out the current user
            func logout() async throws
            
            /// Registers a new user
            func register(firstName: String, lastName: String, email: String, password: String) async throws -> User
        }
        
        /// A protocol for observer pattern
        public protocol Observable {
            associatedtype Event
            
            /// Adds an observer
            func addObserver(_ observer: any Observer<Event>)
            
            /// Removes an observer
            func removeObserver(_ observer: any Observer<Event>)
            
            /// Notifies all observers of an event
            func notifyObservers(_ event: Event)
        }
        
        /// A protocol for observers
        public protocol Observer<Event> {
            associatedtype Event
            
            /// Called when an event occurs
            func onEvent(_ event: Event)
        }
        """

        try protocolContent.write(toFile: testFilesDirectory + "/Protocols.swift", atomically: true, encoding: .utf8)
    }

    private func createExtensionFile(_ testFilesDirectory: String) throws {
        let extensionContent = """
        import Foundation
        
        // Extension to User struct
        extension User {
            /// Format user info for display
            public func formatted() -> String {
                if let email = email {
                    return "\\(fullName) (\\(email))"
                } else {
                    return fullName
                }
            }
            
            /// Create a user with only a full name
            public static func createWithFullName(_ fullName: String) -> User {
                let components = fullName.split(separator: " ")
                let firstName = String(components.first ?? "")
                let lastName = components.count > 1 ? String(components.last ?? "") : ""
                
                return User(firstName: firstName, lastName: lastName)
            }
        }
        
        // Extension adding conformance to a protocol
        extension User: CustomStringConvertible {
            public var description: String {
                return formatted()
            }
        }
        
        // Extension to String
        extension String {
            /// Checks if string is a valid email
            var isValidEmail: Bool {
                let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Za-z]{2,64}"
                let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
                return emailPred.evaluate(with: self)
            }
            
            /// Truncates string to specified length
            func truncated(to length: Int) -> String {
                if self.count <= length {
                    return self
                }
                return String(self.prefix(length)) + "..."
            }
        }
        """

        try extensionContent.write(toFile: testFilesDirectory + "/Extensions.swift", atomically: true, encoding: .utf8)
    }

    private func createEnumFile(_ testFilesDirectory: String) throws {
        let enumContent = """
        import Foundation
        
        /// Represents different user roles
        public enum UserRole: String, Codable {
            case admin
            case editor
            case viewer
            case guest
            
            /// Checks if this role can modify content
            public var canModifyContent: Bool {
                switch self {
                case .admin, .editor:
                    return true
                case .viewer, .guest:
                    return false
                }
            }
            
            /// Returns the display name of the role
            public var displayName: String {
                switch self {
                case .admin:
                    return "Administrator"
                case .editor:
                    return "Content Editor"
                case .viewer:
                    return "Content Viewer"
                case .guest:
                    return "Guest User"
                }
            }
        }
        
        /// Represents API errors
        public enum APIError: Error {
            case networkError(String)
            case authenticationError
            case resourceNotFound
            case serverError(Int)
            case invalidResponse
            case decodingError(Error)
            
            /// Human-readable error description
            public var description: String {
                switch self {
                case .networkError(let message):
                    return "Network error: \\(message)"
                case .authenticationError:
                    return "Authentication failed"
                case .resourceNotFound:
                    return "Resource not found"
                case .serverError(let code):
                    return "Server error with code: \\(code)"
                case .invalidResponse:
                    return "Invalid response received"
                case .decodingError(let error):
                    return "Failed to decode response: \\(error.localizedDescription)"
                }
            }
        }
        """

        try enumContent.write(toFile: testFilesDirectory + "/Enums.swift", atomically: true, encoding: .utf8)
    }

    private func createMixedFile(_ testFilesDirectory: String) throws {
        let mixedContent = """
        import Foundation
        
        // Top-level function
        public func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            return formatter.string(from: NSNumber(value: amount)) ?? "\\(amount)"
        }
        
        // Top-level property
        public let apiVersion = "1.0.0"
        
        // Struct
        public struct Configuration {
            public var apiKey: String
            public var baseURL: URL
            public var timeout: TimeInterval
            
            public init(apiKey: String, baseURL: URL, timeout: TimeInterval = 30.0) {
                self.apiKey = apiKey
                self.baseURL = baseURL
                self.timeout = timeout
            }
        }
        
        // Class
        public class NetworkMonitor {
            public static let shared = NetworkMonitor()
            
            private init() {}
            
            public func startMonitoring() {
                print("Started network monitoring")
            }
            
            public func stopMonitoring() {
                print("Stopped network monitoring")
            }
        }
        
        // Enum
        public enum ConnectionType {
            case wifi
            case cellular
            case ethernet
            case unknown
        }
        
        // Protocol
        public protocol NetworkMonitoring {
            var isConnected: Bool { get }
            var connectionType: ConnectionType { get }
            
            func startMonitoring()
            func stopMonitoring()
        }
        
        // Extension
        extension NetworkMonitor: NetworkMonitoring {
            public var isConnected: Bool {
                return true // Simplified for example
            }
            
            public var connectionType: ConnectionType {
                return .wifi // Simplified for example
            }
        }
        """

        try mixedContent.write(toFile: testFilesDirectory + "/Mixed.swift", atomically: true, encoding: .utf8)
    }
}
