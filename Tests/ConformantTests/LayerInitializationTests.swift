import XCTest
@testable import Conformant

@MainActor
final class LayerInitializationTests: XCTestCase {
    func testLayerWithSinglePackageTarget() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }

        // Setup
        let layer = Layer(name: "UI", packageTarget: "AppUI", fileManager: TestFileReader.shared.fileManager)

        // Create mock declarations
        let uiDecl = createMockDeclaration(name: "View", filePath: "/project/Sources/AppUI/View.swift")
        let domainDecl = createMockDeclaration(name: "Model", filePath: "/project/Sources/AppDomain/Model.swift")
        

        XCTAssertTrue(layer.resideIn(uiDecl), "Declaration in AppUI should be part of UI layer")
        XCTAssertFalse(layer.resideIn(domainDecl), "Declaration in AppDomain should not be part of UI layer")
    }
    
    func testLayerWithMultiplePackageTargets() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }

        // Setup
        let layer = Layer(name: "PersistenceLayer", packageTargets: ["AppData", "CustomPath"], fileManager: TestFileReader.shared.fileManager)

        // Create mock declarations
        let dataDecl = createMockDeclaration(name: "Repository", filePath: "/project/Sources/AppData/Repository.swift")
        let customDecl = createMockDeclaration(name: "Utility", filePath: "/project/Custom/Path/Utility.swift")
        let domainDecl = createMockDeclaration(name: "Service", filePath: "/project/Sources/AppDomain/Service.swift")
        
        // Execute & Verify
        // Note: Same caveat as above - these assertions demonstrate expected behavior
        
        XCTAssertTrue(layer.resideIn(dataDecl), "Declaration in AppData should be part of PersistenceLayer")
        XCTAssertTrue(layer.resideIn(customDecl), "Declaration in CustomPath should be part of PersistenceLayer")
        XCTAssertFalse(layer.resideIn(domainDecl), "Declaration in AppDomain should not be part of PersistenceLayer")
    }
    
    func testCustomPathInPackage() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }

        // Setup
        let layer = Layer(name: "CustomLayer", packageTarget: "CustomPath", fileManager: TestFileReader.shared.fileManager)

        // Create mock declarations
        let customDecl = createMockDeclaration(name: "Utility", filePath: "/project/Custom/Path/Utility.swift")
        let uiDecl = createMockDeclaration(name: "View", filePath: "/project/Sources/AppUI/View.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(customDecl), "Declaration in custom path should be part of CustomLayer")
        XCTAssertFalse(layer.resideIn(uiDecl), "Declaration in AppUI should not be part of CustomLayer")
    }
    
//    func testNestedPackageStructure() {
//        TestFileReader.shared.setupMockFileSystem()
//        defer {
//            TestFileReader.shared.resetMockFileSystem()
//        }
//
//        // Setup for a nested package structure
//        let nestedLayerTarget = Layer(name: "NestedFeature", packageTarget: "FeatureModule", fileManager: TestFileReader.shared.fileManager)
//
//        // Mock nested structure
//        let featureDecl = createMockDeclaration(name: "Feature", filePath: "/project/Features/MyFeature/Sources/FeatureModule/Feature.swift")
//        let mainDecl = createMockDeclaration(name: "View", filePath: "/project/Sources/AppUI/View.swift")
//        
//        // This test assumes the implementation can handle nested package structures
//        XCTAssertTrue(nestedLayerTarget.resideIn(featureDecl), "Declaration in nested feature should be part of NestedFeature layer")
//        XCTAssertFalse(nestedLayerTarget.resideIn(mainDecl), "Declaration in main project should not be part of NestedFeature layer")
//    }
    
    // MARK: - Directory Tests
    
    func testLayerWithDirectory() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }


        // Setup
        let layer = Layer(name: "UtilsLayer", directory: "Utilities")
        
        // Create mock declarations
        let utilsDecl = createMockDeclaration(name: "Logger", filePath: "/project/Utilities/Logger.swift")
        let extensionDecl = createMockDeclaration(name: "StringExtensions", filePath: "/project/Utilities/StringExtensions.swift")
        let uiDecl = createMockDeclaration(name: "View", filePath: "/project/Sources/AppUI/View.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(utilsDecl), "Declaration in Utilities directory should be part of UtilsLayer")
        XCTAssertTrue(layer.resideIn(extensionDecl), "Extensions in Utilities directory should be part of UtilsLayer")
        XCTAssertFalse(layer.resideIn(uiDecl), "Declaration in AppUI should not be part of UtilsLayer")
    }
    
    func testLayerWithDirectoryAndBackslash() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }


        // Setup - test that directory paths with backslashes are handled properly
        let layer = Layer(name: "UtilsLayer", directory: "Utilities\\")
        
        // Create mock declarations
        let utilsDecl = createMockDeclaration(name: "Logger", filePath: "/project/Utilities/Logger.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(utilsDecl), "Declaration in Utilities directory should be part of UtilsLayer despite backslash in directory pattern")
    }
    
    // MARK: - Regex Pattern Tests
    
    func testLayerWithIdentifierPattern() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }

        // Setup
        let layer = Layer(name: "ModelLayer", identifierPattern: ".*Model\\.swift$")
        
        // Create mock declarations
        let modelDecl = createMockDeclaration(name: "Model", filePath: "/project/Sources/AppDomain/Model.swift")
        let userModelDecl = createMockDeclaration(name: "UserModel", filePath: "/project/Sources/AppDomain/UserModel.swift")
        let serviceDecl = createMockDeclaration(name: "Service", filePath: "/project/Sources/AppDomain/Service.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(modelDecl), "Model.swift should be part of ModelLayer")
        XCTAssertTrue(layer.resideIn(userModelDecl), "UserModel.swift should be part of ModelLayer")
        XCTAssertFalse(layer.resideIn(serviceDecl), "Service.swift should not be part of ModelLayer")
    }
    
    func testLayerWithDotDotPattern() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }


        // Setup - test the .. wildcard replacement
        let layer = Layer(name: "DomainLayer", identifierPattern: "/Sources/AppDomain/..swift")
        
        // Create mock declarations
        let modelDecl = createMockDeclaration(name: "Model", filePath: "/project/Sources/AppDomain/Model.swift")
        let serviceDecl = createMockDeclaration(name: "Service", filePath: "/project/Sources/AppDomain/Service.swift")
        let uiDecl = createMockDeclaration(name: "View", filePath: "/project/Sources/AppUI/View.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(modelDecl), "Model.swift should be part of DomainLayer")
        XCTAssertTrue(layer.resideIn(serviceDecl), "Service.swift should be part of DomainLayer")
        XCTAssertFalse(layer.resideIn(uiDecl), "View.swift in UI directory should not be part of DomainLayer")
    }
    
    // MARK: - Custom Predicate Tests
    
    func testLayerWithCustomPredicate() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }


        // Setup
        let layer = Layer(name: "ViewLayer", predicate: { declaration in
            return declaration.name.hasSuffix("View") || declaration.name.hasSuffix("ViewController")
        })
        
        // Create mock declarations
        let viewDecl = createMockDeclaration(name: "View", filePath: "/project/Sources/AppUI/View.swift")
        let vcDecl = createMockDeclaration(name: "ViewController", filePath: "/project/Sources/AppUI/ViewController.swift")
        let modelDecl = createMockDeclaration(name: "Model", filePath: "/project/Sources/AppDomain/Model.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(viewDecl), "View should be part of ViewLayer")
        XCTAssertTrue(layer.resideIn(vcDecl), "ViewController should be part of ViewLayer")
        XCTAssertFalse(layer.resideIn(modelDecl), "Model should not be part of ViewLayer")
    }
    
    func testLayerWithCustomPredicateAndModules() {
        TestFileReader.shared.setupMockFileSystem()
        defer {
            TestFileReader.shared.resetMockFileSystem()
        }


        // Setup
        let layer = Layer(
            name: "ServiceLayer", 
            modules: ["NetworkService", "DatabaseService"],
            predicate: { declaration in
                return declaration.name.hasSuffix("Service")
            }
        )
        
        // Create mock declarations
        let serviceDecl = createMockDeclaration(name: "Service", filePath: "/project/Sources/AppDomain/Service.swift")
        
        // Execute & Verify
        XCTAssertTrue(layer.resideIn(serviceDecl), "Service should be part of ServiceLayer")
        
        // Test containsDependency method
        let importDependency = SwiftDependency(
            name: "NetworkService", 
            kind: .import, 
            location: SourceLocation(file: "", line: 0, column: 0)
        )
        XCTAssertTrue(layer.containsDependency(importDependency), "NetworkService import should be contained in ServiceLayer")
        
        let otherDependency = SwiftDependency(
            name: "OtherModule", 
            kind: .import, 
            location: SourceLocation(file: "", line: 0, column: 0)
        )
        XCTAssertFalse(layer.containsDependency(otherDependency), "OtherModule import should not be contained in ServiceLayer")
    }
}

extension LayerInitializationTests {
    class MockFileManager: FileManager {
        var existingFiles: [String: String] = [:]

        override func fileExists(atPath path: String) -> Bool {
            return existingFiles.keys.contains(path)
        }

        override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
            if let isDir = isDirectory {
                isDir.pointee = path.hasSuffix("/") ? ObjCBool(true) : ObjCBool(false)
            }
            return existingFiles.keys.contains(path)
        }

        override func contents(atPath path: String) -> Data? {
            guard let content = existingFiles[path] else {
                return nil
            }
            return content.data(using: .utf8)
        }
    }

    // Mock implementation to avoid actual file operations
    class TestFileReader {
        nonisolated(unsafe) static let shared = TestFileReader()
        var fileManager = MockFileManager()

        func setupMockFileSystem() {
            // Setup directory structure and files
            let rootPath = "/project/"
            let packageSwiftPath = "\(rootPath)Package.swift"

            // Common directory patterns
            let sourcesPath = "\(rootPath)Sources/"
            let appUIPath = "\(sourcesPath)AppUI/"
            let appDomainPath = "\(sourcesPath)AppDomain/"
            let appDataPath = "\(sourcesPath)AppData/"
            let utilsPath = "\(rootPath)Utilities/"

            // Create mock files
            fileManager.existingFiles[packageSwiftPath] = """
            // swift-tools-version:5.5
            
            import PackageDescription
            
            let package = Package(
                name: "MyApp",
                platforms: [.iOS(.v15)],
                products: [
                    .library(name: "AppUI", targets: ["AppUI"]),
                    .library(name: "AppDomain", targets: ["AppDomain"]),
                    .library(name: "AppData", targets: ["AppData"]),
                ],
                dependencies: [],
                targets: [
                    .target(
                        name: "AppUI",
                        dependencies: ["AppDomain"]
                    ),
                    .target(
                        name: "AppDomain",
                        dependencies: []
                    ),
                    .target(
                        name: "AppData",
                        dependencies: ["AppDomain"]
                    ),
                    .target(
                        name: "CustomPath",
                        dependencies: [],
                        path: "Custom/Path"
                    ),
                    .testTarget(
                        name: "MyAppTests",
                        dependencies: ["AppUI", "AppDomain", "AppData"]
                    )
                ]
            )
            """

            // Files in AppUI
            fileManager.existingFiles["\(appUIPath)View.swift"] = "public struct View {}"
            fileManager.existingFiles["\(appUIPath)ViewController.swift"] = "public class ViewController {}"

            // Files in AppDomain
            fileManager.existingFiles["\(appDomainPath)Model.swift"] = "public struct Model {}"
            fileManager.existingFiles["\(appDomainPath)Service.swift"] = "public protocol Service {}"

            // Files in AppData
            fileManager.existingFiles["\(appDataPath)Repository.swift"] = "public class Repository {}"

            // Files in Utilities
            fileManager.existingFiles["\(utilsPath)Logger.swift"] = "public class Logger {}"
            fileManager.existingFiles["\(utilsPath)StringExtensions.swift"] = "public extension String {}"

            // Custom path
            fileManager.existingFiles["\(rootPath)Custom/Path/Utility.swift"] = "public struct Utility {}"
        }

        func resetMockFileSystem() {
            fileManager.existingFiles = [:]
        }
    }

    func createMockDeclaration(name: String, filePath: String) -> MockDeclaration {
        return MockDeclaration(name: name, filePath: filePath)
    }

    class MockDeclaration: SwiftDeclaration {
        var name: String
        var modifiers: [SwiftModifier] = []
        var annotations: [SwiftAnnotation] = []
        var dependencies: [SwiftDependency] = []
        var filePath: String
        var location: SourceLocation

        init(name: String, filePath: String) {
            self.name = name
            self.filePath = filePath
            self.location = SourceLocation(file: filePath, line: 1, column: 1)
        }

        func hasAnnotation(named: String) -> Bool {
            return annotations.contains { $0.name == named }
        }

        func hasModifier(_ modifier: SwiftModifier) -> Bool {
            return modifiers.contains(modifier)
        }

        func resideInPackage(_ packagePattern: String) -> Bool {
            let regexPattern = packagePattern.replacingOccurrences(of: "..", with: ".*")
            do {
                let regex = try Regex(regexPattern)
                return filePath.contains(regex)
            } catch {
                print("Invalid regex pattern: \(regexPattern) - \(error)")
                return false
            }
        }
    }
}
