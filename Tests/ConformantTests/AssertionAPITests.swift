import XCTest
import SwiftSyntax
import SwiftParser
@testable import Conformant

final class AssertionAPITests: XCTestCase {
    
    var testFilesDirectory: String!
    
    override func setUp() {
        super.setUp()
        
        testFilesDirectory = NSTemporaryDirectory() + "AssertionAPITests_" + UUID().uuidString

        do {
            try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)
            
            try createClassesFile()
            try createStructsFile()
            try createProtocolsFile()
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }
    
    // MARK: - Test File Creation Helpers
    
    private func createClassesFile() throws {
        let classesContent = """
        import Foundation
        
        // Good classes that follow naming conventions
        public final class UserViewModel {
            private let userId: String
            public var name: String = ""
            public var email: String = ""
            
            public init(userId: String) {
                self.userId = userId
            }
            
            public func loadUser() {
                // Implementation
            }
        }
        
        public final class ProductViewModel {
            private let productId: String
            public var title: String = ""
            public var price: Double = 0.0
            
            public init(productId: String) {
                self.productId = productId
            }
            
            public func loadProduct() {
                // Implementation
            }
        }
        
        // Bad class that doesn't follow naming convention
        public class BadViewModel {
            // Missing final modifier
            var data: [String: Any] = [:]
            
            // Missing public modifier
            init() {
                // Implementation
            }
            
            // Missing load method
            func fetchData() {
                // Implementation
            }
        }
        
        // Class with incorrect properties
        public final class IncompleteViewModel {
            // Missing private userId
            public var name: String = ""
            
            public init() {
                // Implementation
            }
            
            // Missing load method
        }
        """
        
        try classesContent.write(toFile: testFilesDirectory + "/ViewModels.swift", atomically: true, encoding: .utf8)
    }
    
    private func createStructsFile() throws {
        let structsContent = """
        import Foundation
        
        // Good structs that follow the conventions
        public struct UserDTO: Codable, Equatable {
            public let id: String
            public let name: String
            public let email: String
            
            public init(id: String, name: String, email: String) {
                self.id = id
                self.name = name
                self.email = email
            }
        }
        
        public struct ProductDTO: Codable, Equatable {
            public let id: String
            public let title: String
            public let price: Double
            
            public init(id: String, title: String, price: Double) {
                self.id = id
                self.title = title
                self.price = price
            }
        }
        
        // Bad struct that doesn't follow conventions
        struct BadDTO {
            // Not public
            let id: String
            var name: String
            
            // Missing Codable conformance
            
            init(id: String, name: String) {
                self.id = id
                self.name = name
            }
        }
        
        // Struct with incorrect properties
        public struct IncompleteDTO: Codable {
            // Missing id
            public let name: String
            
            // Missing Equatable conformance
            
            public init(name: String) {
                self.name = name
            }
        }
        """
        
        try structsContent.write(toFile: testFilesDirectory + "/DTOs.swift", atomically: true, encoding: .utf8)
    }
    
    private func createProtocolsFile() throws {
        let protocolsContent = """
        import Foundation
        
        // Good protocols that follow the conventions
        public protocol Repository {
            associatedtype Entity
            associatedtype ID
            
            func fetch(id: ID) async throws -> Entity
            func save(_ entity: Entity) async throws
            func delete(id: ID) async throws
        }
        
        public protocol Service {
            associatedtype Request
            associatedtype Response
            
            func execute(_ request: Request) async throws -> Response
        }
        
        // Bad protocol that doesn't follow conventions
        protocol BadProtocol {
            // Not public
            func doSomething()
            
            // Missing associatedtype
        }
        
        // Protocol with incorrect methods
        public protocol IncompleteProtocol {
            associatedtype Entity
            
            // Missing fetch method
            func save(_ entity: Entity) async throws
        }
        """
        
        try protocolsContent.write(toFile: testFilesDirectory + "/Protocols.swift", atomically: true, encoding: .utf8)
    }
    
    // MARK: - Assertion API Tests
    
    func testAssertAny() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allViewModels = scope.classes().filter { $0.name.hasSuffix("ViewModel") }
        
        let anyNonFinal = allViewModels.assertAny { !$0.hasModifier(.final) }
        XCTAssertTrue(anyNonFinal, "At least one ViewModel should not be final")
        
        let anyHasLoadUser = allViewModels.assertAny { $0.hasMethod(named: "loadUser") }
        XCTAssertTrue(anyHasLoadUser, "At least one ViewModel should have loadUser method")
        
        let anyHasNonExistent = allViewModels.assertAny { $0.hasMethod(named: "nonExistentMethod") }
        XCTAssertFalse(anyHasNonExistent, "No ViewModel should have nonExistentMethod")
        
        let allDTOs = scope.structs().filter { $0.name.hasSuffix("DTO") }
        
        let anyNonEquatable = allDTOs.assertAny { !$0.implements(protocol: "Equatable") }
        XCTAssertTrue(anyNonEquatable, "At least one DTO should not implement Equatable")
        
        let anyImplementsCustomString = allDTOs.assertAny { $0.implements(protocol: "CustomStringConvertible") }
        XCTAssertFalse(anyImplementsCustomString, "No DTO should implement CustomStringConvertible")
    }
    
    func testAssertNone() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allViewModels = scope.classes().filter { $0.name.hasSuffix("ViewModel") }
        
        let noneHaveController = allViewModels.assertNone { $0.name.contains("Controller") }
        XCTAssertTrue(noneHaveController, "No ViewModel should have Controller in its name")
        
        let noneHaveLoadMethods = allViewModels.assertNone {
            $0.methods.contains { method in method.name.hasPrefix("load") } 
        }
        XCTAssertFalse(noneHaveLoadMethods, "Some ViewModels should have load methods")
        
        let allDTOs = scope.structs().filter { $0.name.hasSuffix("DTO") }
        
        let noneHaveService = allDTOs.assertNone { $0.name.contains("Service") }
        XCTAssertTrue(noneHaveService, "No DTO should have Service in its name")
        
        let noneImplementEquatable = allDTOs.assertNone { $0.implements(protocol: "Equatable") }
        XCTAssertFalse(noneImplementEquatable, "Some DTOs should implement Equatable")
    }
    
    func testAssertTrue() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let goodViewModels = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel" 
        }

        let allGoodAreFinal = goodViewModels.assertTrue {
            $0.hasModifier(.final)
        }
        XCTAssertTrue(allGoodAreFinal, "All good ViewModels should be final")
        
        let allGoodHaveLoadMethod = goodViewModels.assertTrue { viewModel in
            viewModel.methods.contains { method in method.name.hasPrefix("load") }
        }
        XCTAssertTrue(allGoodHaveLoadMethod, "All good ViewModels should have a load method")
        
        let badViewModels = scope.classes().filter {
            $0.name == "BadViewModel" || $0.name == "IncompleteViewModel" 
        }
        
        let allBadAreFinal = badViewModels.assertTrue {
            $0.hasModifier(.final) 
        }
        XCTAssertFalse(allBadAreFinal, "Not all bad ViewModels should be final")
        
        let goodDTOs = scope.structs().filter {
            $0.name == "UserDTO" || $0.name == "ProductDTO" 
        }
        
        let allGoodImplementProtocols = goodDTOs.assertTrue { dto in
            dto.implements(protocol: "Codable") && dto.implements(protocol: "Equatable")
        }

        XCTAssertTrue(allGoodImplementProtocols, "All good DTOs should implement required protocols")
    }
    
    func testAssertFalse() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allViewModels = scope.classes().filter { $0.name.hasSuffix("ViewModel") }
        
        let noneHaveController = allViewModels.assertFalse {
            $0.name.contains("Controller")
        }
        XCTAssertTrue(noneHaveController, "No ViewModel should have Controller in its name")
        
        let noneAreFinal = allViewModels.assertFalse {
            $0.hasModifier(.final)
        }
        XCTAssertFalse(noneAreFinal, "Some ViewModels should be final")
        
        let goodViewModels = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel" 
        }
        
        let noneAreInternal = goodViewModels.assertFalse {
            $0.hasModifier(.internal)
        }
        XCTAssertTrue(noneAreInternal, "No good ViewModel should be internal")
        
        let allProtocols = scope.protocols()
        
        let noneHaveClass = allProtocols.assertFalse {
            $0.name.contains("Class")
        }
        XCTAssertTrue(noneHaveClass, "No protocol should have Class in its name")
    }
    
//    func testAssertionsWithEmptyCollections() {
//        // Test assertions with empty collections
//        let emptyClasses: [any SwiftDeclaration] = []
//        
//        // assertAll should return true for any condition on an empty collection
//        XCTAssertTrue(emptyClasses.assertTrue { _ in false }, "assertAll should return true for empty collections")
//
//        // assertAny should return false for any condition on an empty collection
//        XCTAssertFalse(emptyClasses.assertAny { _ in true }, "assertAny should return false for empty collections")
//        
//        // assertNone should return true for any condition on an empty collection
//        XCTAssertTrue(emptyClasses.assertNone { _ in true }, "assertNone should return true for empty collections")
//        
//        // assertTrue should return true for any condition on an empty collection
//        XCTAssertTrue(emptyClasses.assertTrue { _ in false }, "assertTrue should return true for empty collections")
//        
//        // assertFalse should return true for any condition on an empty collection
//        XCTAssertTrue(emptyClasses.assertFalse { _ in true }, "assertFalse should return true for empty collections")
//    }
    
    func testAssertionsWithComplexPredicates() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allViewModels = scope.classes().filter { $0.name.hasSuffix("ViewModel") }

        let complexPredicate = allViewModels.assertTrue { viewModel in
            let hasCorrectName = viewModel.name.hasSuffix("ViewModel")
            let hasPublicMethod = viewModel.methods.contains { method in
                method.hasModifier(.public)
            }
            
            return hasCorrectName && hasPublicMethod
        }
        
        XCTAssertFalse(complexPredicate, "Not all ViewModels satisfy complex predicate")
        
        let goodViewModels = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel" 
        }
        
        let goodComplexPredicate = goodViewModels.assertTrue { viewModel in
            let hasCorrectName = viewModel.name.hasSuffix("ViewModel")
            
            let hasPublicMethod = viewModel.methods.contains { method in
                method.hasModifier(.public)
            }
            
            let hasPrivateProperty = viewModel.properties.contains { property in
                property.hasModifier(.private)
            }
            
            return hasCorrectName && hasPublicMethod && hasPrivateProperty
        }
        
        XCTAssertTrue(goodComplexPredicate, "All good ViewModels should satisfy complex predicate")
    }
    
    func testCombiningAssertions() {
        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allClasses = scope.classes()
        let allStructs = scope.structs()
        let allProtocols = scope.protocols()

        let classesHaveCorrectNames = allClasses.assertTrue { $0.name.hasSuffix("ViewModel") || $0.name.hasSuffix("Controller") }
        let structsHaveCorrectNames = allStructs.assertTrue { $0.name.hasSuffix("DTO") || $0.name.hasSuffix("Model") }
        let protocolsHaveCorrectNames = allProtocols.assertTrue { !$0.name.hasSuffix("Delegate") || $0.name.hasSuffix("Protocol") }

        let allNamingConventionsFollowed = classesHaveCorrectNames && structsHaveCorrectNames && protocolsHaveCorrectNames
        
        XCTAssertTrue(allNamingConventionsFollowed, "Not all declarations follow naming conventions")

        let goodClasses = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel" 
        }
        let goodStructs = scope.structs().filter { 
            $0.name == "UserDTO" || $0.name == "ProductDTO" 
        }
        let goodProtocols = scope.protocols().filter { 
            $0.name == "Repository" || $0.name == "Service" 
        }

        let goodClassesArePublic = goodClasses.assertTrue { $0.hasModifier(.public) }
        let goodStructsArePublic = goodStructs.assertTrue { $0.hasModifier(.public) }
        let goodProtocolsArePublic = goodProtocols.assertTrue { $0.hasModifier(.public) }

        let allGoodDeclarationsArePublic = goodClassesArePublic && goodStructsArePublic && goodProtocolsArePublic

        XCTAssertTrue(allGoodDeclarationsArePublic, "All good declarations should be public")
    }
}
