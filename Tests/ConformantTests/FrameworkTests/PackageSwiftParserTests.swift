import XCTest
@testable import Conformant

final class PackageSwiftParserTests: XCTestCase {
    
    // MARK: - Basic Parsing Tests
    
    func testBasicParsing() throws {
        // Basic minimal Package.swift content
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "SimplePackage",
            products: [
                .library(name: "SimpleLib", targets: ["SimpleLib"])
            ],
            targets: [
                .target(name: "SimpleLib")
            ]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.name, "SimplePackage")
        XCTAssertEqual(package.products.count, 1)
        XCTAssertEqual(package.products[0].name, "SimpleLib")
        XCTAssertEqual(package.targets.count, 1)
        XCTAssertEqual(package.targets[0].name, "SimpleLib")
    }
    
    func testCompletePackageParsing() throws {
        // A more complete Package.swift with multiple features
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "CompletePackage",
            platforms: [
                .macOS(.v12),
                .iOS(.v15)
            ],
            products: [
                .library(
                    name: "CoreLib",
                    targets: ["CoreLib"]),
                .executable(
                    name: "CLI",
                    targets: ["CLI"])
            ],
            dependencies: [
                .package(url: "https://github.com/example/example.git", from: "1.0.0"),
                .package(name: "Named", url: "https://github.com/named/package.git", .exact("2.0.0"))
            ],
            targets: [
                .target(
                    name: "CoreLib",
                    dependencies: [
                        .product(name: "Example", package: "example")
                    ],
                    path: "Sources/Core"),
                .executableTarget(
                    name: "CLI",
                    dependencies: ["CoreLib"],
                    path: "Sources/CLI"),
                .testTarget(
                    name: "CoreLibTests",
                    dependencies: ["CoreLib"])
            ],
            swiftLanguageVersions: [.v5]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        // Test basic properties
        XCTAssertEqual(package.name, "CompletePackage")
        
        // Test platforms
        XCTAssertEqual(package.platforms.count, 2)
        XCTAssertEqual(package.platforms[0].name, "macOS")
        XCTAssertEqual(package.platforms[0].version, "12")
        XCTAssertEqual(package.platforms[1].name, "iOS")
        XCTAssertEqual(package.platforms[1].version, "15")
        
        // Test products
        XCTAssertEqual(package.products.count, 2)
        XCTAssertEqual(package.products[0].name, "CoreLib")
        
        if case .library(let type) = package.products[0].type {
            XCTAssertEqual(type, .automatic)
        } else {
            XCTFail("Expected library product type")
        }
        
        XCTAssertEqual(package.products[1].name, "CLI")
        if case .executable = package.products[1].type {
            // Success
        } else {
            XCTFail("Expected executable product type")
        }
        
        // Test dependencies
        XCTAssertEqual(package.dependencies.count, 2)
        XCTAssertEqual(package.dependencies[0].url, "https://github.com/example/example.git")
        XCTAssertNil(package.dependencies[0].name)
        
        if case .upToNextMajor(let version) = package.dependencies[0].requirement {
            XCTAssertEqual(version, "1.0.0")
        } else {
            XCTFail("Expected upToNextMajor requirement")
        }
        
        XCTAssertEqual(package.dependencies[1].name, "Named")
        XCTAssertEqual(package.dependencies[1].url, "https://github.com/named/package.git")
        
        if case .exact(let version) = package.dependencies[1].requirement {
            XCTAssertEqual(version, "2.0.0")
        } else {
            XCTFail("Expected exact requirement")
        }
        
        // Test targets
        XCTAssertEqual(package.targets.count, 3)
        
        // Core library target
        XCTAssertEqual(package.targets[0].name, "CoreLib")
        XCTAssertEqual(package.targets[0].type, .regular)
        XCTAssertEqual(package.targets[0].path, "Sources/Core")
        XCTAssertEqual(package.targets[0].dependencies.count, 1)
        
        if case .product(let name, let packageName) = package.targets[0].dependencies[0] {
            XCTAssertEqual(name, "Example")
            XCTAssertEqual(packageName, "example")
        } else {
            XCTFail("Expected product dependency")
        }
        
        // CLI target
        XCTAssertEqual(package.targets[1].name, "CLI")
        XCTAssertEqual(package.targets[1].type, .regular)
        XCTAssertEqual(package.targets[1].path, "Sources/CLI")
        XCTAssertEqual(package.targets[1].dependencies.count, 1)
        
        if case .byName(let name) = package.targets[1].dependencies[0] {
            XCTAssertEqual(name, "CoreLib")
        } else {
            XCTFail("Expected byName dependency")
        }
        
        // Test target
        XCTAssertEqual(package.targets[2].name, "CoreLibTests")
        XCTAssertEqual(package.targets[2].type, .test)
        XCTAssertEqual(package.targets[2].dependencies.count, 1)
        
        if case .byName(let name) = package.targets[2].dependencies[0] {
            XCTAssertEqual(name, "CoreLib")
        } else {
            XCTFail("Expected byName dependency")
        }
        
        // Test language versions
        XCTAssertEqual(package.swiftLanguageVersions.count, 1)
        XCTAssertEqual(package.swiftLanguageVersions[0], "5")
    }
    
    // MARK: - Edge Case Tests
    
    func testPackageWithEmptyCollections() throws {
        // Test parsing a package with empty collections
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "EmptyCollections",
            platforms: [],
            products: [],
            dependencies: [],
            targets: [],
            swiftLanguageVersions: []
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.name, "EmptyCollections")
        XCTAssertTrue(package.platforms.isEmpty)
        XCTAssertTrue(package.products.isEmpty)
        XCTAssertTrue(package.dependencies.isEmpty)
        XCTAssertTrue(package.targets.isEmpty)
        XCTAssertTrue(package.swiftLanguageVersions.isEmpty)
    }
    
    func testPackageWithComplexFormatting() throws {
        // Test parsing a package with complex whitespace, comments, and formatting
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "ComplexFormatting",
            // Comment about platforms
            platforms: [
                /* Multi-line
                   Comment */
                .macOS(.v12),
                
                .iOS(.v15) // Inline comment
            ],
            products: [
                .library(
                    name: "ComplexLib", // Comment
                    
                    // Comment about type
                    type: .static,
                    
                    targets: ["ComplexLib", 
                              "Helper"])
            ],
            
            /* This is a 
               multi-line comment about dependencies */
            dependencies: [
                .package(
                    url: "https://github.com/example/example.git", 
                    .upToNextMajor(from: "1.0.0")
                )
            ],
            targets: [
                .target(name: "ComplexLib"),
                .target(
                    name: "Helper",
                    path: "Sources/Helper"
                )
            ]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.name, "ComplexFormatting")
        XCTAssertEqual(package.platforms.count, 2)
        XCTAssertEqual(package.products.count, 1)
        
        // Verify that complex formatting didn't break parsing
        if case .library(let type) = package.products[0].type {
            XCTAssertEqual(type, .static)
        } else {
            XCTFail("Expected static library product type")
        }
        
        XCTAssertEqual(package.products[0].targets.count, 2)
        XCTAssertEqual(package.products[0].targets, ["ComplexLib", "Helper"])
        XCTAssertEqual(package.dependencies.count, 1)
        XCTAssertEqual(package.targets.count, 2)
    }
    
    func testAllDependencyRequirementTypes() throws {
        // Test parsing all types of dependency requirements
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "AllRequirementTypes",
            dependencies: [
                .package(url: "https://github.com/example/exact.git", .exact("1.0.0")),
                .package(url: "https://github.com/example/major.git", .upToNextMajor(from: "2.0.0")),
                .package(url: "https://github.com/example/minor.git", .upToNextMinor(from: "3.0.0")),
                .package(url: "https://github.com/example/branch.git", .branch("develop")),
                .package(url: "https://github.com/example/revision.git", .revision("abc123")),
                .package(url: "https://github.com/example/range.git", .range(from: "1.0.0", to: "2.0.0"))
            ]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.dependencies.count, 6)
        
        // Test .exact
        if case .exact(let version) = package.dependencies[0].requirement {
            XCTAssertEqual(version, "1.0.0")
        } else {
            XCTFail("Expected exact requirement")
        }
        
        // Test .upToNextMajor
        if case .upToNextMajor(let version) = package.dependencies[1].requirement {
            XCTAssertEqual(version, "2.0.0")
        } else {
            XCTFail("Expected upToNextMajor requirement")
        }
        
        // Test .upToNextMinor
        if case .upToNextMinor(let version) = package.dependencies[2].requirement {
            XCTAssertEqual(version, "3.0.0")
        } else {
            XCTFail("Expected upToNextMinor requirement")
        }
        
        // Test .branch
        if case .branch(let name) = package.dependencies[3].requirement {
            XCTAssertEqual(name, "develop")
        } else {
            XCTFail("Expected branch requirement")
        }
        
        // Test .revision
        if case .revision(let id) = package.dependencies[4].requirement {
            XCTAssertEqual(id, "abc123")
        } else {
            XCTFail("Expected revision requirement")
        }
        
        // Test .range
        if case .range(let from, let to) = package.dependencies[5].requirement {
            XCTAssertEqual(from, "1.0.0")
            XCTAssertEqual(to, "2.0.0")
        } else {
            XCTFail("Expected range requirement")
        }
    }
    
    func testAllTargetTypes() throws {
        // Test parsing all target types
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "AllTargetTypes",
            targets: [
                .target(name: "RegularTarget"),
                .testTarget(name: "TestTarget"),
                .systemLibrary(name: "SystemTarget"),
                .binaryTarget(name: "BinaryTarget", path: "binary.xcframework"),
                .plugin(name: "PluginTarget", capability: .buildTool())
            ]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.targets.count, 5)
        XCTAssertEqual(package.targets[0].type, .regular)
        XCTAssertEqual(package.targets[1].type, .test)
        XCTAssertEqual(package.targets[2].type, .system)
        XCTAssertEqual(package.targets[3].type, .binary)
        XCTAssertEqual(package.targets[4].type, .plugin)
    }
    
    func testResourceRules() throws {
        // Test parsing resource rules
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "ResourceRules",
            targets: [
                .target(
                    name: "ResourceTarget",
                    resources: [
                        .process("Process.txt"),
                        .copy("Copy.png")
                    ]
                )
            ]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.targets.count, 1)
        XCTAssertEqual(package.targets[0].resources.count, 2)
        
        XCTAssertEqual(package.targets[0].resources[0].path, "Process.txt")
        XCTAssertEqual(package.targets[0].resources[0].rule, .process)
        
        XCTAssertEqual(package.targets[0].resources[1].path, "Copy.png")
        XCTAssertEqual(package.targets[0].resources[1].rule, .copy)
    }
    
    func testAllTargetDependencyTypes() throws {
        // Test parsing all target dependency types
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "AllDependencyTypes",
            dependencies: [
                .package(name: "ExternalLib", url: "https://github.com/example/lib.git", from: "1.0.0")
            ],
            targets: [
                .target(
                    name: "AllDeps",
                    dependencies: [
                        "SimpleString",
                        .target(name: "TargetDep"),
                        .product(name: "Product", package: "ExternalLib"),
                        .product(name: "LocalProduct")
                    ]
                ),
                .target(name: "SimpleString"),
                .target(name: "TargetDep")
            ]
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.targets.count, 3)
        XCTAssertEqual(package.targets[0].dependencies.count, 4)
        
        // Test string dependency (byName)
        if case .byName(let name) = package.targets[0].dependencies[0] {
            XCTAssertEqual(name, "SimpleString")
        } else {
            XCTFail("Expected byName dependency")
        }
        
        // Test target dependency
        if case .target(let name) = package.targets[0].dependencies[1] {
            XCTAssertEqual(name, "TargetDep")
        } else {
            XCTFail("Expected target dependency")
        }
        
        // Test product dependency with package
        if case .product(let name, let packageName) = package.targets[0].dependencies[2] {
            XCTAssertEqual(name, "Product")
            XCTAssertEqual(packageName, "ExternalLib")
        } else {
            XCTFail("Expected product dependency with package")
        }
        
        // Test product dependency without package
        if case .product(let name, let packageName) = package.targets[0].dependencies[3] {
            XCTAssertEqual(name, "LocalProduct")
            XCTAssertNil(packageName)
        } else {
            XCTFail("Expected product dependency without package")
        }
    }
    
    func testPackageWithCAndCXXLanguageStandards() throws {
        // Test parsing C and C++ language standards
        let content = """
        // swift-tools-version:5.5
        import PackageDescription

        let package = Package(
            name: "LanguageStandards",
            cLanguageStandard: .c11,
            cxxLanguageStandard: .cxx14
        )
        """
        
        let parser = PackageSwiftParser(content: content)
        let package = try parser.parse()
        
        XCTAssertEqual(package.name, "LanguageStandards")
        XCTAssertEqual(package.cLanguageStandard, "c11")
        XCTAssertEqual(package.cxxLanguageStandard, "cxx14")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidPackageParsing() {
        // Test parsing an invalid package
        let content = """
        // This is not a valid Package.swift file
        import Foundation

        struct MyStruct {
            let value: Int
        }
        """
        
        let parser = PackageSwiftParser(content: content)
        
        // The parser should not crash, but it might return a package with default values
        // or it might throw an error depending on your implementation
        do {
            let package = try parser.parse()
            // If it doesn't throw, at least the name should be "Unknown" or some default
            XCTAssertEqual(package.name, "Unknown")
        } catch {
            // If it throws, that's also acceptable for invalid content
            XCTAssertNotNil(error)
        }
    }
    
    func testParserWithEmptyContent() {
        // Test with empty content
        let parser = PackageSwiftParser(content: "")
        
        do {
            let package = try parser.parse()
            // Should use default values
            XCTAssertEqual(package.name, "Unknown")
            XCTAssertTrue(package.platforms.isEmpty)
            XCTAssertTrue(package.products.isEmpty)
            XCTAssertTrue(package.dependencies.isEmpty)
            XCTAssertTrue(package.targets.isEmpty)
        } catch {
            // Or it might throw an error, which is fine too
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Additional Test Extensions

extension PackageFile.Product.ProductType: Equatable {
    public static func == (lhs: PackageFile.Product.ProductType, rhs: PackageFile.Product.ProductType) -> Bool {
        switch (lhs, rhs) {
        case (.executable, .executable):
            return true
        case (.library(let lhsType), .library(let rhsType)):
            return lhsType == rhsType
        default:
            return false
        }
    }
}

extension PackageFile.Product.ProductType.LibraryType: Equatable {
    public static func == (lhs: PackageFile.Product.ProductType.LibraryType, rhs: PackageFile.Product.ProductType.LibraryType) -> Bool {
        switch (lhs, rhs) {
        case (.dynamic, .dynamic), (.static, .static), (.automatic, .automatic):
            return true
        default:
            return false
        }
    }
}

extension PackageFile.Target.TargetType: Equatable {
    public static func == (lhs: PackageFile.Target.TargetType, rhs: PackageFile.Target.TargetType) -> Bool {
        switch (lhs, rhs) {
        case (.regular, .regular), (.test, .test), (.system, .system), (.binary, .binary), (.plugin, .plugin):
            return true
        default:
            return false
        }
    }
}

extension PackageFile.Resource.Rule: Equatable {
    public static func == (lhs: PackageFile.Resource.Rule, rhs: PackageFile.Resource.Rule) -> Bool {
        switch (lhs, rhs) {
        case (.process, .process), (.copy, .copy):
            return true
        default:
            return false
        }
    }
}
