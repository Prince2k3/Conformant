import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class FreezingArchRuleTests: XCTestCase {
    func testFreezingRuleWithFileStore() throws {
        let (testFilesDirectory, violationsDirectory) = try makeSUT()
        defer {
            cleanup(testFilesDirectory, violationsDirectory: violationsDirectory)
        }

        // Create a file path for storing violations
        let violationFilePath = violationsDirectory + "/domain_violations.json"

        // Run the test twice to verify freezing behavior
        for iteration in 1...2 {
            // Create a scope for the test directory
            let scope = Conformant.scopeFromDirectory(testFilesDirectory)

            // Test architecture with freezing rule
            let result = scope.assertArchitecture { rules in
                // Define layers
                let domain = Layer(name: "Domain", directory: "Domain")
                let data = Layer(name: "Data", directory: "Data")

                // Register layers
                rules.defineLayer(domain)
                rules.defineLayer(data)

                // Create a rule and freeze it
                let rule = domain.mustNotDependOn(data)
                rules.addFreezing(rule, toFile: violationFilePath)
            }

            if iteration == 1 {
                // First run should detect the violation
                XCTAssertFalse(result, "First run should detect the violation")

                // Verify that the violation was stored
                let store = FileViolationStore(filePath: violationFilePath)
                let storedViolations = store.loadViolations()
                XCTAssertFalse(storedViolations.isEmpty, "Violations should be stored")

                // Verify the content of the stored violation
                if let firstViolation = storedViolations.first {
                    XCTAssertTrue(firstViolation.filePath.contains("DomainWithViolation.swift"),
                                  "Stored violation should reference the correct file")
                    XCTAssertEqual(firstViolation.declarationName, "GetUserUseCase",
                                   "Stored violation should reference the correct declaration")
                }
            } else {
                // Second run should ignore the already-detected violation
                XCTAssertTrue(result, "Second run should pass as violations are frozen")
            }
        }
    }

    func testFreezingRuleWithInMemoryStore() throws {
        let (testFilesDirectory, violationsDirectory) = try makeSUT()
        defer {
            cleanup(testFilesDirectory, violationsDirectory: violationsDirectory)
        }

        // Create an in-memory store
        let violationStore = InMemoryViolationStore()

        // Create a scope for the test directory
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // First run - should detect and store violations
        var result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)

            // Create a rule and freeze it with the in-memory store
            let rule = domain.mustNotDependOn(data)
            rules.addFreezing(rule, using: violationStore)
        }

        XCTAssertFalse(result, "First run should detect the violation")

        // Verify that the violation was stored
        let storedViolations = violationStore.loadViolations()
        XCTAssertFalse(storedViolations.isEmpty, "Violations should be stored")

        // Second run - should ignore the stored violation
        result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)

            // Create a rule and freeze it with the same in-memory store
            let rule = domain.mustNotDependOn(data)
            rules.addFreezing(rule, using: violationStore)
        }

        XCTAssertTrue(result, "Second run should pass as violations are frozen")
    }

    func testFreezeAllRules() throws {
        let (testFilesDirectory, violationsDirectory) = try makeSUT()
        defer {
            cleanup(testFilesDirectory, violationsDirectory: violationsDirectory)
        }

        // Create a scope for the test directory
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // First run - should detect and store violations
        var result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")
            let presentation = Layer(name: "Presentation", directory: "Presentation")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)
            rules.defineLayer(presentation)

            // Add multiple rules
            rules.add(domain.mustNotDependOn(data))
            rules.add(data.mustNotDependOn(presentation))

            // Freeze all rules
            rules.freezeAllRules(inDirectory: violationsDirectory)
        }

        XCTAssertFalse(result, "First run should detect the violation")

        // Verify that violation files were created
        let fileManager = FileManager.default
        let filesInDir = try? fileManager.contentsOfDirectory(atPath: violationsDirectory)
        XCTAssertNotNil(filesInDir, "Should be able to list files in violations directory")
        XCTAssertTrue(filesInDir?.count ?? 0 > 0, "Should have created violation files")

        // Second run - should ignore the stored violations
        result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")
            let presentation = Layer(name: "Presentation", directory: "Presentation")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)
            rules.defineLayer(presentation)

            // Add multiple rules
            rules.add(domain.mustNotDependOn(data))
            rules.add(data.mustNotDependOn(presentation))

            // Freeze all rules
            rules.freezeAllRules(inDirectory: violationsDirectory)
        }

        XCTAssertTrue(result, "Second run should pass as violations are frozen")
    }

    func testViolationRemoval() throws {
        let (testFilesDirectory, violationsDirectory) = try makeSUT()
        defer {
            cleanup(testFilesDirectory, violationsDirectory: violationsDirectory)
        }

        // Create a file path for storing violations
        let violationFilePath = violationsDirectory + "/domain_violations.json"

        // First run - detect and store violation
        var scope = Conformant.scopeFromDirectory(testFilesDirectory)
        var result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)

            // Create a rule and freeze it
            let rule = domain.mustNotDependOn(data)
            rules.addFreezing(rule, toFile: violationFilePath)
        }

        XCTAssertFalse(result, "First run should detect the violation")

        // Verify that violations were stored
        let store = FileViolationStore(filePath: violationFilePath)
        var storedViolations = store.loadViolations()
        XCTAssertFalse(storedViolations.isEmpty, "Violations should be stored")

        // Now fix the violation by creating a new compliant file
        do {
            // Create a fixed version of the file (no Data dependency)
            let fixedFile = """
            // DomainWithViolation.swift - Fixed
            
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

            // Override the file with the fixed version
            try fixedFile.write(toFile: testFilesDirectory + "/Domain/DomainWithViolation.swift", atomically: true, encoding: .utf8)

            // Run the test again with the fixed code
            scope = Conformant.scopeFromDirectory(testFilesDirectory)
            result = scope.assertArchitecture { rules in
                // Define layers
                let domain = Layer(name: "Domain", directory: "Domain")
                let data = Layer(name: "Data", directory: "Data")

                // Register layers
                rules.defineLayer(domain)
                rules.defineLayer(data)

                // Create a rule and freeze it
                let rule = domain.mustNotDependOn(data)
                rules.addFreezing(rule, toFile: violationFilePath)
            }

            XCTAssertTrue(result, "Run with fixed code should pass")

            // Check that the violation was removed from storage
            storedViolations = store.loadViolations()
            XCTAssertTrue(storedViolations.isEmpty, "Violations should be removed after fixing")

        } catch {
            XCTFail("Failed to create fixed file: \(error)")
        }
    }

    func testNewViolationsAfterFreezing() throws {
        let (testFilesDirectory, violationsDirectory) = try makeSUT()
        defer {
            cleanup(testFilesDirectory, violationsDirectory: violationsDirectory)
        }

        // Create a file path for storing violations
        let violationFilePath = violationsDirectory + "/domain_violations.json"

        // First run - detect and store initial violation
        var scope = Conformant.scopeFromDirectory(testFilesDirectory)
        var result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)

            // Create a rule and freeze it
            let rule = domain.mustNotDependOn(data)
            rules.addFreezing(rule, toFile: violationFilePath)
        }

        XCTAssertFalse(result, "First run should detect the violation")

        // Second run - add a new violation
        do {
            // Create a new file with another violation
            let newViolationFile = """
            // AnotherViolation.swift
            
            import Foundation
            import Data  // Another violation: Domain should not import Data
            
            public class SaveUserUseCase {
                private let repository: UserRepositoryImpl // Violation: Using a Data layer class
                
                public init(repository: UserRepositoryImpl) {
                    self.repository = repository
                }
                
                public func execute(user: User) async throws {
                    try await repository.saveUser(user)
                }
            }
            """

            // Write the new violation file
            try newViolationFile.write(toFile: testFilesDirectory + "/Domain/AnotherViolation.swift", atomically: true, encoding: .utf8)

            // Run the test again with the new violation
            scope = Conformant.scopeFromDirectory(testFilesDirectory)
            result = scope.assertArchitecture { rules in
                // Define layers
                let domain = Layer(name: "Domain", directory: "Domain")
                let data = Layer(name: "Data", directory: "Data")

                // Register layers
                rules.defineLayer(domain)
                rules.defineLayer(data)

                // Create a rule and freeze it
                let rule = domain.mustNotDependOn(data)
                rules.addFreezing(rule, toFile: violationFilePath)
            }

            XCTAssertFalse(result, "Run with new violation should fail despite freezing")

            // Verify that both violations are now stored
            let store = FileViolationStore(filePath: violationFilePath)
            let storedViolations = store.loadViolations()
            XCTAssertEqual(storedViolations.count, 2, "Should store at two violations")

        } catch {
            XCTFail("Failed to create new violation file: \(error)")
        }
    }

    func testCustomLineMatcher() throws {
        let (testFilesDirectory, violationsDirectory) = try makeSUT()
        defer {
            cleanup(testFilesDirectory, violationsDirectory: violationsDirectory)
        }

        // Create a file path for storing violations
        let violationFilePath = violationsDirectory + "/custom_matcher_violations.json"

        // Create a custom line matcher that is more strict
        struct StrictFileNameMatcher: ViolationLineMatcher {
            func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool {
                // Only match violations in the exact same file (ignoring line numbers)
                return stored.filePath == actual.sourceDeclaration.filePath &&
                stored.ruleDescription == actual.ruleDescription
            }
        }

        // First run - detect and store violation with custom matcher
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let data = Layer(name: "Data", directory: "Data")

            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(data)

            // Create a rule with custom matcher
            let rule = domain.mustNotDependOn(data)
            let customMatcher = StrictFileNameMatcher()
            rules.addFreezing(rule, using: FileViolationStore(filePath: violationFilePath), matching: customMatcher)
        }

        XCTAssertFalse(result, "First run should detect the violation")

        // Create a second violation file with the same violation but different class name
        do {
            let secondViolationFile = """
                // SimilarViolation.swift
                
                import Foundation
                import Data  // Similar violation: Domain should not import Data
                
                public class AnotherUseCase {
                    private let repository: UserRepositoryImpl // Violation: Using a Data layer class
                    
                    public init(repository: UserRepositoryImpl) {
                        self.repository = repository
                    }
                    
                    public func execute() {
                        // Implementation
                    }
                }
                """

            try secondViolationFile.write(toFile: testFilesDirectory + "/Domain/SimilarViolation.swift", atomically: true, encoding: .utf8)

            // Run test again - with default matcher this would be considered frozen
            // but with our custom matcher it should be detected as a new violation
            let updatedScope = Conformant.scopeFromDirectory(testFilesDirectory)
            let updatedResult = updatedScope.assertArchitecture { rules in
                // Define layers
                let domain = Layer(name: "Domain", directory: "Domain")
                let data = Layer(name: "Data", directory: "Data")

                // Register layers
                rules.defineLayer(domain)
                rules.defineLayer(data)

                // Create a rule with custom matcher
                let rule = domain.mustNotDependOn(data)
                let customMatcher = StrictFileNameMatcher()
                rules.addFreezing(rule, using: FileViolationStore(filePath: violationFilePath), matching: customMatcher)
            }

            // Should fail because the custom matcher only freezes by file, not by class name
            XCTAssertFalse(updatedResult, "Custom matcher should detect new violation in different file")

            // Verify that both violations are now stored
            let store = FileViolationStore(filePath: violationFilePath)
            let storedViolations = store.loadViolations()
            XCTAssertGreaterThanOrEqual(storedViolations.count, 2, "Should store at least two violations")

            // Check that violations are from different files
            let violationFiles = Set(storedViolations.map { $0.filePath })
            XCTAssertEqual(violationFiles.count, 2, "Violations should be from at least two different files")

        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
}

extension FreezingArchRuleTests {
    func makeSUT() throws -> (String, String) {
        // Create a temporary directory for test files
        let testFilesDirectory = NSTemporaryDirectory() + "FreezingArchRuleTests_" + UUID().uuidString

        // Create a temporary directory for violation stores
        let violationsDirectory = NSTemporaryDirectory() + "FreezingArchRuleViolationsTests_" + UUID().uuidString

        try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: violationsDirectory, withIntermediateDirectories: true)

        // Create directories for different layers
        let domainPath = testFilesDirectory + "/Domain"
        let presentationPath = testFilesDirectory + "/Presentation"
        let dataPath = testFilesDirectory + "/Data"

        try FileManager.default.createDirectory(atPath: domainPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: presentationPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: dataPath, withIntermediateDirectories: true)

        // Create test files with violations
        try createDomainFiles(in: domainPath)
        try createPresentationFiles(in: presentationPath)
        try createDataFiles(in: dataPath)

        // Create violation file
        try createViolationFile(in: domainPath)

        return (testFilesDirectory, violationsDirectory)
    }

    func cleanup(_ testFilesDirectory: String, violationsDirectory: String) {
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
        try? FileManager.default.removeItem(atPath: violationsDirectory)
    }

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

        try userFile.write(toFile: path + "/User.swift", atomically: true, encoding: .utf8)
        try repositoryFile.write(toFile: path + "/UserRepository.swift", atomically: true, encoding: .utf8)
    }

    private func createPresentationFiles(in path: String) throws {
        // View model with appropriate imports
        let viewModelFile = """
        // UserViewModel.swift
        
        import Foundation
        import Domain
        
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
                }
            }
        }
        """

        try viewModelFile.write(toFile: path + "/UserViewModel.swift", atomically: true, encoding: .utf8)
    }

    private func createDataFiles(in path: String) throws {
        // Repository implementation
        let repositoryFile = """
        // UserRepositoryImpl.swift
        
        import Foundation
        import Domain
        
        public class UserRepositoryImpl: UserRepository {
            private let apiClient: APIClient
            
            public init(apiClient: APIClient) {
                self.apiClient = apiClient
            }
            
            public func getUser(id: String) async throws -> User {
                // Implementation
                return User(id: id, name: "Test User", email: "test@example.com")
            }
            
            public func saveUser(_ user: User) async throws {
                // Implementation
            }
        }
        """

        try repositoryFile.write(toFile: path + "/UserRepositoryImpl.swift", atomically: true, encoding: .utf8)
    }

    private func createViolationFile(in path: String) throws {
        // File with architectural violation - Domain depends on Data layer
        let violationFile = """
        // DomainWithViolation.swift
        
        import Foundation
        import Data  // Violation: Domain should not import Data
        
        public class GetUserUseCase {
            private let repository: UserRepository
            private let dataClass: UserRepositoryImpl // Violation: Using a Data layer class
            
            public init(repository: UserRepository, dataClass: UserRepositoryImpl) {
                self.repository = repository
                self.dataClass = dataClass
            }
            
            public func execute(userId: String) async throws -> User {
                return try await repository.getUser(id: userId)
            }
        }
        """

        try violationFile.write(toFile: path + "/DomainWithViolation.swift", atomically: true, encoding: .utf8)
    }

}
