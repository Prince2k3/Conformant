import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class ArchitectureRulesTests: XCTestCase {
    func testArchitectureRules() {
        let testFilesDirectory = makeSUT()

        defer {
            cleanup(testFilesDirectory)
        }

        // Get the scope from the test directory
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Testing architecture rules using the new Layer API
        let result = scope.assertArchitecture { rules in
            // Define layers using directory paths
            let domain = Layer(name: "Domain", directory: "Domain")
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            let data = Layer(name: "Data", directory: "Data")
            let core = Layer(name: "Core", directory: "Core")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(presentation)
            rules.defineLayer(data)
            rules.defineLayer(core)

            // Define clean architecture rules
            
            // Domain should not depend on other layers
            rules.add(domain.dependsOnNothing())
            
            // Presentation can depend on Domain and Core
            rules.add(presentation.onlyDependsOn(domain, core))
            
            // Data can depend on Domain and Core
            rules.add(data.onlyDependsOn(domain, core))
            
            // Core should not depend on any other layer
            rules.add(core.dependsOnNothing())

            // Presentation must not depend on Data
            rules.add(presentation.mustNotDependOn(data))
            
            // Data must not depend on Presentation
            rules.add(data.mustNotDependOn(presentation))
        }
        
        // The test files should pass the architecture rules
        XCTAssertTrue(result, "Architecture rules should pass with the test files")
    }
    
    func testArchitectureRuleViolations() {
        let testFilesDirectory = makeSUT()

        defer {
            cleanup(testFilesDirectory)
        }

        do {
            let violationPath = testFilesDirectory + "/Domain/ViolationExample.swift"
            let violationFile = """
            // ViolationExample.swift
            
            import Foundation
            import Presentation // This violates architecture - Domain shouldn't import Presentation
            
            public class DomainViolation {
                private let viewModel: UserViewModel // Using a presentation layer class
                
                public init(viewModel: UserViewModel) {
                    self.viewModel = viewModel
                }
                
                public func doSomething() {
                    // Implementation
                }
            }
            """
            
            try violationFile.write(toFile: violationPath, atomically: true, encoding: .utf8)
            
            let scope = Conformant.scopeFromDirectory(testFilesDirectory)

            let result = scope.assertArchitecture { rules in
                // Define layers
                let domain = Layer(name: "Domain", directory: "Domain")
                let presentation = Layer(name: "Presentation", directory: "Presentation")
                
                // Register layers
                rules.defineLayer(domain)
                rules.defineLayer(presentation)
                
                // Domain should not depend on Presentation
                rules.add(domain.mustNotDependOn(presentation))
            }
            
            XCTAssertFalse(result, "Architecture rules should fail with the violation")
            
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
    
    func testLayerByDirectory() {
        let testFilesDirectory = makeSUT()

        defer {
            cleanup(testFilesDirectory)
        }

        // Test creating layers by directory
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Define layers using directory
        let domainLayer = Layer(name: "Domain", directory: "Domain")
        let presentationLayer = Layer(name: "Presentation", directory: "Presentation")
        
        // Test that declarations are correctly assigned to layers
        let allDeclarations = scope.declarations()
        
        let domainDeclarations = allDeclarations.filter { domainLayer.resideIn($0) }
        let presentationDeclarations = allDeclarations.filter { presentationLayer.resideIn($0) }
        
        // Verify that domain declarations are correctly identified
        XCTAssertTrue(domainDeclarations.contains { $0.name == "User" }, "User should be in Domain layer")
        XCTAssertTrue(domainDeclarations.contains { $0.name == "UserRepository" }, "UserRepository should be in Domain layer")
        XCTAssertTrue(domainDeclarations.contains { $0.name == "GetUserUseCase" }, "GetUserUseCase should be in Domain layer")
        
        // Verify that presentation declarations are correctly identified
        XCTAssertTrue(presentationDeclarations.contains { $0.name == "UserViewModel" }, "UserViewModel should be in Presentation layer")
        XCTAssertTrue(presentationDeclarations.contains { $0.name == "UserView" }, "UserView should be in Presentation layer")
        
        // Verify that declarations are assigned to only one layer
        let inBothLayers = allDeclarations.filter { domainLayer.resideIn($0) && presentationLayer.resideIn($0) }
        XCTAssertTrue(inBothLayers.isEmpty, "No declaration should be in both Domain and Presentation layers")
    }
    
    func testLayerByModule() {
        let testFilesDirectory = makeSUT()

        defer {
            cleanup(testFilesDirectory)
        }

        // Test creating layers by module (import statements)
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Define layers using modules
        let domainModule = Layer(name: "DomainModule", directory: "Domain")
        let coreModule = Layer(name: "CoreModule", directory: "Core")

        // Find declarations that import these modules
        let allDeclarations = scope.declarations()
        
        let importsDomain = allDeclarations.filter { domainModule.resideIn($0) }

        let importsCore = allDeclarations.filter { coreModule.resideIn($0) }

        // Verify that declarations importing Domain are correctly identified
        XCTAssertTrue(importsDomain.contains { $0.name == "User" }, "User should import Domain")
        XCTAssertTrue(importsDomain.contains { $0.name == "GetUserUseCase" }, "GetUserUseCase should import Domain")
        XCTAssertTrue(importsDomain.contains { $0.name == "UserRepository" }, "UserRepository should import Domain")

        // Verify that declarations importing Core are correctly identified
        XCTAssertTrue(importsCore.contains { $0.name == "Logger" }, "Logger should import Core")
        XCTAssertTrue(importsCore.contains { $0.name == "APIClient" }, "APIClient should import Core")
    }
    
    func testLayerWithCustomPredicate() {
        let testFilesDirectory = makeSUT()

        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Define a layer containing all view models
        let viewModelLayer = Layer(name: "ViewModels", predicate: { decl in
            decl.name.hasSuffix("ViewModel")
        })
        
        // Define a layer containing all repositories
        let repositoryLayer = Layer(name: "Repositories", predicate: { decl in
            decl.name.contains("Repository")
        })
        
        // Test that declarations are correctly assigned to layers
        let allDeclarations = scope.declarations()
        
        let viewModels = allDeclarations.filter { viewModelLayer.resideIn($0) }
        let repositories = allDeclarations.filter { repositoryLayer.resideIn($0) }
        
        // Verify that view models are correctly identified
        XCTAssertEqual(viewModels.count, 1, "Should find exactly one view model")
        XCTAssertTrue(viewModels.contains { $0.name == "UserViewModel" }, "UserViewModel should be in ViewModels layer")
        
        // Verify that repositories are correctly identified
        XCTAssertEqual(repositories.count, 2, "Should find exactly two repositories")
        XCTAssertTrue(repositories.contains { $0.name == "UserRepository" }, "UserRepository should be in Repositories layer")
        XCTAssertTrue(repositories.contains { $0.name == "UserRepositoryImpl" }, "UserRepositoryImpl should be in Repositories layer")
    }
    
    func testCombinedLayerRules() {
        let testFilesDirectory = makeSUT()

        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let result = scope.assertArchitecture { rules in
            // Define layers using different methods
            let domainLayer = Layer(name: "Domain", directory: "Domain")
            let viewModelLayer = Layer(name: "ViewModels", predicate: { $0.name.hasSuffix("ViewModel") })
            let repositoryLayer = Layer(name: "Repositories", predicate: { $0.name.contains("Repository") })
            
            // Register layers
            rules.defineLayer(domainLayer)
            rules.defineLayer(viewModelLayer)
            rules.defineLayer(repositoryLayer)
            
            // ViewModels can depend on Domain but not on Repositories directly
            rules.add(viewModelLayer.dependsOn(domainLayer))
            rules.add(viewModelLayer.mustNotDependOn(repositoryLayer))
            
            // Domain repositories can't depend on view models
            rules.add(repositoryLayer.mustNotDependOn(viewModelLayer))
        }
        
        XCTAssertTrue(result, "Combined layer architecture rules should pass")
    }
}

extension ArchitectureRulesTests {
    func makeSUT() -> String {
        let testFilesDirectory = NSTemporaryDirectory() + "ArchitectureRulesTests_" + UUID().uuidString

        do {
            try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)

            let domainPath = testFilesDirectory + "/Domain"
            let presentationPath = testFilesDirectory + "/Presentation"
            let dataPath = testFilesDirectory + "/Data"
            let corePath = testFilesDirectory + "/Core"

            try FileManager.default.createDirectory(atPath: domainPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: presentationPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: dataPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: corePath, withIntermediateDirectories: true)

            try createDomainFiles(in: domainPath)
            try createPresentationFiles(in: presentationPath)
            try createDataFiles(in: dataPath)
            try createCoreFiles(in: corePath)
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }

        return testFilesDirectory
    }

    func cleanup(_ testFilesDirectory: String) {
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }

    // MARK: - Test File Creation Helpers

    private func createDomainFiles(in path: String) throws {
        // User entity
        let userFile = """
        // User.swift
        
        import Foundation
        
        public struct User {
            public let id: String
            public let name: String
            public let email: String
            
            public init(id: String, name: String, email: String) {
                self.id = id
                self.name = name
                self.email = email
            }
        }
        """

        // Repository interface
        let repositoryFile = """
        // UserRepository.swift
        
        import Foundation
        
        public protocol UserRepository {
            func getUser(id: String) async throws -> User
            func saveUser(_ user: User) async throws
        }
        """

        // Use case
        let useCaseFile = """
        // GetUserUseCase.swift
        
        import Foundation
        
        public class GetUserUseCase {
            private let repository: UserRepository
            
            public init(repository: UserRepository) {
                self.repository = repository
            }
            
            public func execute(userId: String) async throws -> User {
                return try await repository.getUser(id: userId)
            }
        }
        """

        try userFile.write(toFile: path + "/User.swift", atomically: true, encoding: .utf8)
        try repositoryFile.write(toFile: path + "/UserRepository.swift", atomically: true, encoding: .utf8)
        try useCaseFile.write(toFile: path + "/GetUserUseCase.swift", atomically: true, encoding: .utf8)
    }

    private func createPresentationFiles(in path: String) throws {
        // View model
        let viewModelFile = """
        // UserViewModel.swift
        
        import Foundation
        import Domain
        import Core
        
        public class UserViewModel {
            private let getUserUseCase: GetUserUseCase
            public var user: User?
            public var error: Error?
            
            public init(getUserUseCase: GetUserUseCase) {
                self.getUserUseCase = getUserUseCase
            }
            
            public func loadUser(id: String) async {
                do {
                    user = try await getUserUseCase.execute(userId: id)
                } catch {
                    self.error = error
                    Logger.log(error.localizedDescription)
                }
            }
        }
        """

        // View
        let viewFile = """
        // UserView.swift
        
        import Foundation
        import Domain
        
        public class UserView {
            private let viewModel: UserViewModel
            
            public init(viewModel: UserViewModel) {
                self.viewModel = viewModel
            }
            
            public func display() {
                if let user = viewModel.user {
                    print("User: \\(user.name)")
                } else if let error = viewModel.error {
                    print("Error: \\(error.localizedDescription)")
                }
            }
        }
        """

        try viewModelFile.write(toFile: path + "/UserViewModel.swift", atomically: true, encoding: .utf8)
        try viewFile.write(toFile: path + "/UserView.swift", atomically: true, encoding: .utf8)
    }

    private func createDataFiles(in path: String) throws {
        // Repository implementation
        let repositoryFile = """
        // UserRepositoryImpl.swift
        
        import Foundation
        import Domain
        import Core
        
        public class UserRepositoryImpl: UserRepository {
            private let apiClient: APIClient
            
            public init(apiClient: APIClient) {
                self.apiClient = apiClient
            }
            
            public func getUser(id: String) async throws -> User {
                // This would make an API call in a real implementation
                return User(id: id, name: "Test User", email: "test@example.com")
            }
            
            public func saveUser(_ user: User) async throws {
                // This would make an API call in a real implementation
                Logger.log("Saving user: \\(user.name)")
            }
        }
        """

        // Data model
        let dataModelFile = """
        // UserResponse.swift
        
        import Foundation
        
        struct UserResponse: Decodable {
            let id: String
            let name: String
            let email: String
            
            func toDomain() -> User {
                return User(id: id, name: name, email: email)
            }
        }
        """

        try repositoryFile.write(toFile: path + "/UserRepositoryImpl.swift", atomically: true, encoding: .utf8)
        try dataModelFile.write(toFile: path + "/UserResponse.swift", atomically: true, encoding: .utf8)
    }

    private func createCoreFiles(in path: String) throws {
        // Logger utility
        let loggerFile = """
        // Logger.swift
        
        import Foundation
        
        public enum LogLevel {
            case debug
            case info
            case error
        }
        
        public class Logger {
            public static func log(_ message: String, level: LogLevel = .info) {
                print("[\\(level)]: \\(message)")
            }
        }
        """

        // API client
        let apiClientFile = """
        // APIClient.swift
        
        import Foundation
        
        public class APIClient {
            private let baseURL: URL
            
            public init(baseURL: URL) {
                self.baseURL = baseURL
            }
            
            public func fetch<T: Decodable>(endpoint: String) async throws -> T {
                // This would make a network request in a real implementation
                fatalError("Not implemented")
            }
            
            public func send<T: Encodable>(data: T, endpoint: String) async throws {
                // This would make a network request in a real implementation
                fatalError("Not implemented")
            }
        }
        """

        try loggerFile.write(toFile: path + "/Logger.swift", atomically: true, encoding: .utf8)
        try apiClientFile.write(toFile: path + "/APIClient.swift", atomically: true, encoding: .utf8)
    }
}
