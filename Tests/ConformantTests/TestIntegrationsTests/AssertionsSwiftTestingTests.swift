import Testing
import Foundation
import SwiftSyntax
import SwiftParser
@testable import Conformant

@Suite
struct AssertionsSwiftTestingTests {
    @Test
    func assertTrue() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let goodViewModels = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel"
        }

        let allGoodAreFinal = goodViewModels.assertTrue {
            $0.hasModifier(.final)
        }
        #expect(allGoodAreFinal, "All good ViewModels should be final")

        let allGoodHaveLoadMethod = goodViewModels.assertTrue { viewModel in
            viewModel.methods.contains { method in method.name.hasPrefix("load") }
        }
        #expect(allGoodHaveLoadMethod, "All good ViewModels should have a load method")

        let goodDTOs = scope.structs().filter {
            $0.name == "UserDTO" || $0.name == "ProductDTO"
        }

        let allGoodImplementProtocols = goodDTOs.assertTrue { dto in
            dto.implements(protocol: "Codable") && dto.implements(protocol: "Equatable")
        }

        #expect(allGoodImplementProtocols, "All good DTOs should implement required protocols")
    }

    @Test
    func assertFalse() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let goodViewModels = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel"
        }

        goodViewModels.assertFalse(message: "All good ViewModels should be final") {
            $0.hasModifier(.final)
        }

        goodViewModels.assertFalse(message: "All good ViewModels should have a load method") { viewModel in
            viewModel.methods.contains { method in method.name.hasPrefix("load") }
        }

        let goodDTOs = scope.structs().filter {
            $0.name == "UserDTO" || $0.name == "ProductDTO"
        }

        goodDTOs.assertFalse(message: "All good DTOs should implement required protocols") { dto in
            dto.implements(protocol: "Codable") && dto.implements(protocol: "Equatable")
        }
    }

    @Test
    func assertionsWithComplexPredicates() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allViewModels = scope.classes().filter { $0.name.hasSuffix("ViewModel") }

        let complexPredicate = allViewModels.assertTrue { viewModel in
            let hasCorrectName = viewModel.name.hasSuffix("ViewModel")
            let hasPublicMethod = viewModel.methods.contains { method in
                method.hasModifier(.public)
            }

            return hasCorrectName && hasPublicMethod
        }

        #expect(!complexPredicate, "Not all ViewModels satisfy complex predicate")

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

        #expect(goodComplexPredicate, "All good ViewModels should satisfy complex predicate")
    }

    @Test
    func combiningAssertions() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        let allClasses = scope.classes()
        let allStructs = scope.structs()
        let allProtocols = scope.protocols()

        let classesHaveCorrectNames = allClasses.assertTrue {
            $0.name.hasSuffix("ViewModel") || $0.name.hasSuffix("Controller")
        }

        let structsHaveCorrectNames = allStructs.assertTrue {
            $0.name.hasSuffix("DTO") || $0.name.hasSuffix("Model")
        }

        let protocolsHaveCorrectNames = allProtocols.assertTrue {
            !$0.name.hasSuffix("Delegate") || $0.name.hasSuffix("Protocol")
        }

        let allNamingConventionsFollowed = classesHaveCorrectNames && structsHaveCorrectNames && protocolsHaveCorrectNames

        #expect(allNamingConventionsFollowed, "Not all declarations follow naming conventions")

        let goodClasses = scope.classes().filter {
            $0.name == "UserViewModel" || $0.name == "ProductViewModel"
        }
        let goodStructs = scope.structs().filter {
            $0.name == "UserDTO" || $0.name == "ProductDTO"
        }
        let goodProtocols = scope.protocols().filter {
            $0.name == "Repository" || $0.name == "Service"
        }

        let goodClassesArePublic = goodClasses.assertTrue {
            $0.hasModifier(.public)
        }

        let goodStructsArePublic = goodStructs.assertTrue {
            $0.hasModifier(.public)
        }

        let goodProtocolsArePublic = goodProtocols.assertTrue {
            $0.hasModifier(.public)
        }

        let allGoodDeclarationsArePublic = goodClassesArePublic && goodStructsArePublic && goodProtocolsArePublic

        #expect(allGoodDeclarationsArePublic, "All good declarations should be public")
    }
}

extension AssertionsSwiftTestingTests {
    func makeSUT() -> String {
        let testFilesDirectory = NSTemporaryDirectory() + "AssertionAPITests_" + UUID().uuidString

        do {
            try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)

            try createClassesFile(testFilesDirectory)
            try createStructsFile(testFilesDirectory)
            try createProtocolsFile(testFilesDirectory)
        } catch {
            Issue.record("Failed to set up test environment: \(error)")
        }

        return testFilesDirectory
    }

    func cleanup(_ testFilesDirectory: String) {
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }

    private func createClassesFile(_ testFilesDirectory: String) throws {
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

    private func createStructsFile(_ testFilesDirectory: String) throws {
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

    private func createProtocolsFile(_ testFilesDirectory: String) throws {
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
}
