import XCTest
@testable import Conformant
import SwiftSyntax
import SwiftParser

final class FilteringAPITests: XCTestCase {
    func testNameFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Test withNameSuffix
        let viewControllers: [SwiftClassDeclaration] = scope.classes().withNameSuffix("ViewController")
        XCTAssertEqual(viewControllers.count, 2, "Should find 2 view controller classes")
        XCTAssertTrue(viewControllers.contains { $0.name == "BaseViewController" }, "Should find BaseViewController")
        XCTAssertTrue(viewControllers.contains { $0.name == "HomeViewController" }, "Should find HomeViewController")
        
        // Test withNamePrefix
        let networkClasses = scope.declarations().withNamePrefix("Network")
        XCTAssertEqual(networkClasses.count, 4, "Should find 4 Network* declarations")
        XCTAssertTrue(networkClasses.contains { $0.name == "NetworkService" }, "Should find NetworkService")
        XCTAssertTrue(networkClasses.contains { $0.name == "NetworkConfiguration" }, "Should find NetworkConfiguration")
        XCTAssertTrue(networkClasses.contains { $0.name == "NetworkError" }, "Should find NetworkError")
        XCTAssertTrue(networkClasses.contains { $0.name == "NetworkManager" }, "Should find NetworkManager")

        // Test withNameContaining
        let userDeclarations = scope.declarations().withNameContaining("User")
        XCTAssertEqual(userDeclarations.count, 4, "Should find 4 declarations containing 'User'")

        // Test withName
        let homeVC = scope.classes().withName("HomeViewController")
        XCTAssertEqual(homeVC.count, 1, "Should find exactly 1 HomeViewController")
        XCTAssertEqual(homeVC.first?.name, "HomeViewController", "Should find HomeViewController by exact name")
        
        // Test withNames
        let specificModels = scope.declarations().withNames(["User", "Product"])
        XCTAssertEqual(specificModels.count, 2, "Should find exactly 2 models")
        XCTAssertTrue(specificModels.contains { $0.name == "User" }, "Should find User by name")
        XCTAssertTrue(specificModels.contains { $0.name == "Product" }, "Should find Product by name")
        
        // Test withNameMatching
        let viewModelPattern = scope.declarations().withNameMatching(".*ViewModel")
        XCTAssertEqual(viewModelPattern.count, 2, "Should find 2 view models")
        XCTAssertTrue(viewModelPattern.contains { $0.name == "ProductViewModel" }, "Should find ProductViewModel")
        XCTAssertTrue(viewModelPattern.contains { $0.name == "ViewModel" }, "Should find ViewModel protocol")
    }
    
    // MARK: - Modifier Filtering Tests
    
    func testModifierFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Test withModifier
        let publicDeclarations = scope.declarations().withModifier(.public)
        XCTAssertTrue(publicDeclarations.count > 0, "Should find public declarations")
        
        let openDeclarations = scope.declarations().withModifier(.open)
        XCTAssertTrue(openDeclarations.count > 0, "Should find open declarations")

        let finalClasses = scope.classes().withModifier(.final)
        XCTAssertEqual(finalClasses.count, 1, "Should find 1 final class")
        XCTAssertEqual(finalClasses.first?.name, "HomeViewController", "The final class should be HomeViewController")
        
        // Test withAnyModifier
        let publicOrOpenDeclarations = scope.declarations().withAnyModifier(.public, .open)
        XCTAssertTrue(publicOrOpenDeclarations.count > 0, "Should find declarations with either public or private modifier")
        XCTAssertTrue(publicOrOpenDeclarations.count >= publicDeclarations.count + openDeclarations.count,
                      "Should find at least as many declarations as public and open combined")
        
        // Test withAllModifiers
        let publicFinalClasses = scope.classes().withAllModifiers(.public, .final)
        XCTAssertEqual(publicFinalClasses.count, 1, "Should find 1 public final class")
        XCTAssertEqual(publicFinalClasses.first?.name, "HomeViewController", "The public final class should be HomeViewController")
        
        // Test withoutModifier
        let nonFinalClasses = scope.classes().withoutModifier(.final)
        XCTAssertTrue(nonFinalClasses.count > 0, "Should find non-final classes")
        XCTAssertFalse(nonFinalClasses.contains { $0.name == "HomeViewController" }, "HomeViewController should not be in non-final classes")
        
        // Test withoutAnyModifier
        let nonPublicOrPrivateDeclarations = scope.declarations().withoutAnyModifier(.public, .private)
        XCTAssertTrue(nonPublicOrPrivateDeclarations.count > 0, "Should find declarations with neither public nor private modifier")
    }
    
    // MARK: - Annotation Filtering Tests
    
    func testAnnotationFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Test withAnnotation
        let availableDeclarations = scope.declarations().withAnnotation(named: "available")
        XCTAssertEqual(availableDeclarations.count, 1, "Should find 1 declaration with @available")
        XCTAssertEqual(availableDeclarations.first?.name, "HomeViewController", "HomeViewController should have @available annotation")
        
        // Test withAnyAnnotation
        // Would need more test files with different annotations to properly test
        
        // Test withoutAnnotation
        let nonAvailableDeclarations = scope.declarations().withoutAnnotation(named: "available")
        XCTAssertTrue(nonAvailableDeclarations.count > 0, "Should find declarations without @available")
        XCTAssertFalse(nonAvailableDeclarations.contains { $0.name == "HomeViewController" }, 
                      "HomeViewController should not be in declarations without @available")
    }
    
    // MARK: - Location Filtering Tests
    
    func testLocationFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Test inFile
        let classesFilePath = testFilesDirectory + "/Classes.swift"
        let classesFileDeclarations = scope.declarations().inFile(classesFilePath)
        XCTAssertTrue(classesFileDeclarations.count > 0, "Should find declarations in Classes.swift")
        XCTAssertTrue(classesFileDeclarations.contains { $0.name == "HomeViewController" }, 
                     "HomeViewController should be in Classes.swift")
        
        // Test inFilePathContaining
        let enumsDeclarations = scope.declarations().inFilePathContaining("Enums.swift")
        XCTAssertTrue(enumsDeclarations.count > 0, "Should find declarations in Enums.swift")
        XCTAssertTrue(enumsDeclarations.contains { $0.name == "NetworkError" }, 
                     "NetworkError should be in Enums.swift")
        
        // Test inPackage - for this example, we'll use directory name as package
        let functionsPackageDeclarations = scope.declarations().inPackage("Functions")
        XCTAssertTrue(functionsPackageDeclarations.count > 0, "Should find declarations in Functions package")
        XCTAssertTrue(functionsPackageDeclarations.contains { $0.name == "formatCurrency" }, 
                     "formatCurrency should be in Functions package")
    }
    
    // MARK: - Class-Specific Filtering Tests
    
    func testClassSpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let classes = scope.classes()
        
        // Test extending
        let viewControllerSubclasses = classes.extending(class: "BaseViewController")
        XCTAssertEqual(viewControllerSubclasses.count, 1, "Should find 1 subclass of BaseViewController")
        XCTAssertEqual(viewControllerSubclasses.first?.name, "HomeViewController", 
                      "HomeViewController should extend BaseViewController")
        
        // Test implementing
        // Need class implementing protocol to test properly
        
        // Test havingMethod
        let classesWithViewDidLoad = classes.havingMethod(named: "viewDidLoad")
        XCTAssertEqual(classesWithViewDidLoad.count, 2, "Should find 2 classes with viewDidLoad method")
        XCTAssertTrue(classesWithViewDidLoad.contains { $0.name == "BaseViewController" }, 
                     "BaseViewController should have viewDidLoad method")
        XCTAssertTrue(classesWithViewDidLoad.contains { $0.name == "HomeViewController" }, 
                     "HomeViewController should have viewDidLoad method")
        
        // Test havingProperty
        let classesWithLoadingProperty = classes.havingProperty(named: "isLoading")
        XCTAssertEqual(classesWithLoadingProperty.count, 1, "Should find 1 class with isLoading property")
        XCTAssertEqual(classesWithLoadingProperty.first?.name, "BaseViewController", 
                      "BaseViewController should have isLoading property")
        
        // Test final
        let finalClasses = classes.final()
        XCTAssertEqual(finalClasses.count, 1, "Should find 1 final class")
        XCTAssertEqual(finalClasses.first?.name, "HomeViewController", "The final class should be HomeViewController")
        
        // Test subclassable
        let subclassableClasses = classes.subclassable()
        XCTAssertTrue(subclassableClasses.count > 0, "Should find subclassable classes")
        XCTAssertTrue(subclassableClasses.contains { $0.name == "BaseViewController" }, 
                     "BaseViewController should be subclassable")
        XCTAssertFalse(subclassableClasses.contains { $0.name == "HomeViewController" }, 
                      "HomeViewController should not be subclassable")
    }
    
    // MARK: - Struct-Specific Filtering Tests
    
    func testStructSpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let structs = scope.structs()
        
        // Test implementing
        let codableStructs = structs.implementing(protocol: "Codable")
        XCTAssertTrue(codableStructs.count > 0, "Should find structs implementing Codable")
        XCTAssertTrue(codableStructs.contains { $0.name == "User" }, "User should implement Codable")
        
        let identifiableStructs = structs.implementing(protocol: "Identifiable")
        XCTAssertTrue(identifiableStructs.count > 0, "Should find structs implementing Identifiable")
        XCTAssertTrue(identifiableStructs.contains { $0.name == "User" }, "User should implement Identifiable")
        
        // Test implementingAny
        let anyProtocolStructs = structs.implementingAny(protocols: "Codable", "Equatable")
        XCTAssertTrue(anyProtocolStructs.count > 0, "Should find structs implementing any of the protocols")
        
        // Test implementingAll
        let allProtocolsStructs = structs.implementingAll(protocols: "Codable", "Equatable")
        XCTAssertTrue(allProtocolsStructs.count > 0, "Should find structs implementing all protocols")
        XCTAssertTrue(allProtocolsStructs.contains { $0.name == "User" }, 
                     "User should implement all required protocols")
        
        // Test havingMethod
        let structsWithEqualMethod = structs.havingMethod(named: "==")
        XCTAssertTrue(structsWithEqualMethod.count > 0, "Should find structs with equality method")
        XCTAssertTrue(structsWithEqualMethod.contains { $0.name == "User" }, "User should have equality method")
        
        // Test havingProperty
        let structsWithIdProperty = structs.havingProperty(named: "id")
        XCTAssertEqual(structsWithIdProperty.count, 3, "Should find 3 structs with id property")
        XCTAssertTrue(structsWithIdProperty.contains { $0.name == "User" }, "User should have id property")
        XCTAssertTrue(structsWithIdProperty.contains { $0.name == "ProductViewModel" }, 
                     "ProductViewModel should have id property")
    }
    
    // MARK: - Protocol-Specific Filtering Tests
    
    func testProtocolSpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let protocols = scope.protocols()
        
        // Test inheriting
        let repoProtocols = protocols.inheriting(protocol: "Repository")
        XCTAssertEqual(repoProtocols.count, 1, "Should find 1 protocol inheriting from Repository")
        XCTAssertEqual(repoProtocols.first?.name, "UserRepository", 
                      "UserRepository should inherit from Repository")
        
        // Test requiringMethod
        let protocolsRequiringFetch = protocols.requiringMethod(named: "fetch")
        XCTAssertEqual(protocolsRequiringFetch.count, 1, "Should find 1 protocol requiring fetch method")
        XCTAssertEqual(protocolsRequiringFetch.first?.name, "Repository", 
                      "Repository should require fetch method")
        
        let protocolsRequiringSave = protocols.requiringMethod(named: "save")
        XCTAssertEqual(protocolsRequiringSave.count, 1, "Should find 1 protocol requiring save method")
        
        // Test requiringProperty
        let protocolsRequiringIsLoading = protocols.requiringProperty(named: "isLoading")
        XCTAssertEqual(protocolsRequiringIsLoading.count, 1, "Should find 1 protocol requiring isLoading property")
        XCTAssertEqual(protocolsRequiringIsLoading.first?.name, "ViewModel", 
                      "ViewModel should require isLoading property")
    }
    
    // MARK: - Function-Specific Filtering Tests
    
    func testFunctionSpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let functions = scope.functions()
        
        // Test returningType
        let stringFunctions = functions.returningType("String")
        XCTAssertTrue(stringFunctions.count > 0, "Should find functions returning String")
        XCTAssertTrue(stringFunctions.contains { $0.name == "formatCurrency" }, 
                     "formatCurrency should return String")
        
        // Test returningAnyType
        let nonVoidFunctions = functions.returningAnyType()
        XCTAssertTrue(nonVoidFunctions.count > 0, "Should find functions returning a value")
        
        // Test returningVoid
        let voidFunctions = functions.returningVoid()
        XCTAssertTrue(voidFunctions.count > 0, "Should find void functions")
        XCTAssertTrue(voidFunctions.contains { $0.name == "logMessage" }, 
                     "logMessage should return void")
        
        // Test havingParameter
        let functionsWithMessage = functions.havingParameter(named: "message")
        XCTAssertTrue(functionsWithMessage.count > 0, "Should find functions with message parameter")
        XCTAssertTrue(functionsWithMessage.contains { $0.name == "logMessage" }, 
                     "logMessage should have message parameter")
        
        // Test withParameterCount
        let functionsWithTwoParams = functions.withParameterCount(2)
        XCTAssertTrue(functionsWithTwoParams.count > 0, "Should find functions with exactly 2 parameters")
        XCTAssertTrue(functionsWithTwoParams.contains { $0.name == "formatCurrency" }, 
                     "formatCurrency should have 2 parameters")
        
        // Test withMinParameterCount
        let functionsWithAtLeastTwoParams = functions.withMinParameterCount(2)
        XCTAssertTrue(functionsWithAtLeastTwoParams.count > 0, "Should find functions with at least 2 parameters")
        XCTAssertTrue(functionsWithAtLeastTwoParams.contains { $0.name == "formatCurrency" }, 
                     "formatCurrency should have at least 2 parameters")
        XCTAssertTrue(functionsWithAtLeastTwoParams.contains { $0.name == "calculateDistance" }, 
                     "calculateDistance should have at least 2 parameters")
        
        // Test async
        let asyncFunctions = functions.async()
        XCTAssertTrue(asyncFunctions.count > 0, "Should find async functions")
        XCTAssertTrue(asyncFunctions.contains { $0.name == "fetchData" }, 
                     "fetchData should be async")
        
        // Test throwing
        let throwingFunctions = functions.throwing()
        XCTAssertTrue(throwingFunctions.count > 0, "Should find throwing functions")
        XCTAssertTrue(throwingFunctions.contains { $0.name == "fetchData" }, 
                     "fetchData should be throwing")
    }
    
    // MARK: - Property-Specific Filtering Tests
    
    func testPropertySpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Get properties from the Product struct
        let productProperties = scope.structs()
            .withName("Product")
            .first?.properties ?? []
        
        // Test ofType
        let stringProperties = productProperties.ofType("String")
        XCTAssertTrue(stringProperties.count > 0, "Should find String properties")
        XCTAssertTrue(stringProperties.contains { $0.name == "name" }, "name should be a String property")
        XCTAssertTrue(stringProperties.contains { $0.name == "id" }, "id should be a String property")
        
        let doubleProperties = productProperties.ofType("Double")
        XCTAssertTrue(doubleProperties.count > 0, "Should find Double properties")
        XCTAssertTrue(doubleProperties.contains { $0.name == "price" }, "price should be a Double property")
        
        // Test computed
        let computedProperties = productProperties.computed()
        XCTAssertTrue(computedProperties.count > 0, "Should find computed properties")
        XCTAssertTrue(computedProperties.contains { $0.name == "formattedPrice" }, 
                     "formattedPrice should be a computed property")
        XCTAssertTrue(computedProperties.contains { $0.name == "taxIncludedPrice" }, 
                     "taxIncludedPrice should be a computed property")
        
        // Test stored
        let storedProperties = productProperties.stored()
        XCTAssertTrue(storedProperties.count > 0, "Should find stored properties")
        XCTAssertTrue(storedProperties.contains { $0.name == "id" }, "id should be a stored property")
        XCTAssertTrue(storedProperties.contains { $0.name == "name" }, "name should be a stored property")
        XCTAssertTrue(storedProperties.contains { $0.name == "price" }, "price should be a stored property")
        
        // Test withInitialValue
        let propertiesWithInitialValues = productProperties.withInitialValue()
        XCTAssertTrue(propertiesWithInitialValues.count > 0, "Should find properties with initial values")
        XCTAssertTrue(propertiesWithInitialValues.contains { $0.name == "id" }, 
                     "id should have an initial value")
        XCTAssertTrue(propertiesWithInitialValues.contains { $0.name == "isAvailable" }, 
                     "isAvailable should have an initial value")
        
        // Test withoutInitialValue
        let propertiesWithoutInitialValues = productProperties.withoutInitialValue()
        XCTAssertTrue(propertiesWithoutInitialValues.count > 0, "Should find properties without initial values")
        XCTAssertTrue(propertiesWithoutInitialValues.contains { $0.name == "description" }, 
                     "description should not have an initial value")
    }
    
    // MARK: - Enum-Specific Filtering Tests
    
    func testEnumSpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let enums = scope.enums()
        
        // Test implementing
        let errorEnums = enums.implementing(protocol: "Error")
        XCTAssertEqual(errorEnums.count, 1, "Should find 1 enum implementing Error")
        XCTAssertEqual(errorEnums.first?.name, "NetworkError", "NetworkError should implement Error")
        
        let equatableEnums = enums.implementing(protocol: "Equatable")
        XCTAssertEqual(equatableEnums.count, 1, "Should find 1 enum implementing Equatable")
        XCTAssertEqual(equatableEnums.first?.name, "NetworkError", "NetworkError should implement Equatable")
        
        // Test withRawType
        let stringEnums = enums.withRawType("String")
        XCTAssertEqual(stringEnums.count, 3, "Should find 3 enums with String raw type")
        XCTAssertTrue(stringEnums.contains { $0.name == "ApiEndpoint" }, "ApiEndpoint should have String raw type")
        XCTAssertTrue(stringEnums.contains { $0.name == "UserRole" }, "UserRole should have String raw type")
        XCTAssertTrue(stringEnums.contains { $0.name == "LogLevel" }, "LogLevel should have String raw type")

        // Test havingCase
        let enumsWithLightCase = enums.havingCase(named: "light")
        XCTAssertEqual(enumsWithLightCase.count, 1, "Should find 1 enum with 'light' case")
        XCTAssertEqual(enumsWithLightCase.first?.name, "Theme", "Theme should have 'light' case")
        
        let enumsWithUnauthorizedCase = enums.havingCase(named: "unauthorized")
        XCTAssertEqual(enumsWithUnauthorizedCase.count, 1, "Should find 1 enum with 'unauthorized' case")
        XCTAssertEqual(enumsWithUnauthorizedCase.first?.name, "NetworkError", "NetworkError should have 'unauthorized' case")
        
        // Test withAssociatedValues
        let enumsWithAssociatedValues = enums.withAssociatedValues()
        XCTAssertEqual(enumsWithAssociatedValues.count, 1, "Should find 1 enum with associated values")
        XCTAssertEqual(enumsWithAssociatedValues.first?.name, "NetworkError", "NetworkError should have associated values")
        
        // Test withRawValues
        let enumsWithRawValues = enums.withRawValues()
        XCTAssertEqual(enumsWithRawValues.count, 1, "Should find 1 enums with raw values")
        XCTAssertTrue(enumsWithRawValues.contains { $0.name == "ApiEndpoint" }, "ApiEndpoint should have raw values")
    }
    
    // MARK: - Import-Specific Filtering Tests
    
    func testImportSpecificFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)
        let imports = scope.imports()
        
        // Test ofModule
        let foundationImports = imports.ofModule("Foundation")
        XCTAssertTrue(foundationImports.count > 0, "Should find Foundation imports")
        
        let uikitImports = imports.ofModule("UIKit")
        XCTAssertTrue(uikitImports.count > 0, "Should find UIKit imports")
        
        // Test ofKind - requires custom parsing to be fully tested
        
        // Test includingType
        let uiTableViewImports = imports.includingType("UITableView")
        XCTAssertTrue(uiTableViewImports.count > 0, "Should find imports including UITableView")
        
        // Test fromAppleFrameworks
        let appleImports = imports.fromAppleFrameworks()
        XCTAssertTrue(appleImports.count > 0, "Should find imports from Apple frameworks")
        XCTAssertTrue(appleImports.contains { $0.name == "UIKit" }, "Should find UIKit imports")
        XCTAssertTrue(appleImports.contains { $0.name == "SwiftUI" }, "Should find SwiftUI imports")
        XCTAssertTrue(appleImports.contains { $0.name == "CoreData" }, "Should find CoreData imports")
        
        // Test fromThirdPartyLibraries
        let thirdPartyImports = imports.fromThirdPartyLibraries()
        XCTAssertTrue(thirdPartyImports.count > 0, "Should find imports from third-party libraries")
        XCTAssertTrue(thirdPartyImports.contains { $0.name == "Alamofire" }, "Should find Alamofire imports")
        XCTAssertTrue(thirdPartyImports.contains { $0.name == "SnapKit" }, "Should find SnapKit imports")
        XCTAssertTrue(thirdPartyImports.contains { $0.name == "RxSwift" }, "Should find RxSwift imports")
        
        // Test withSubmodules
        let importsWithSubmodules = imports.withSubmodules()
        XCTAssertTrue(importsWithSubmodules.count > 0, "Should find imports with submodules")
        XCTAssertTrue(importsWithSubmodules.contains { $0.name == "UIKit" && $0.submodules.contains("UITableView") }, 
                     "Should find UIKit.UITableView import")
        XCTAssertTrue(importsWithSubmodules.contains { $0.name == "CoreData" && $0.submodules.contains("NSManagedObject") }, 
                     "Should find CoreData.NSManagedObject import")
    }
    
    // MARK: - Composite Filtering Tests
    
    func testCompositeFiltering() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Test chaining different filters
        let publicFinalClasses = scope.classes()
            .withModifier(.public)
            .withModifier(.final)
        
        XCTAssertEqual(publicFinalClasses.count, 1, "Should find 1 public final class")
        XCTAssertEqual(publicFinalClasses.first?.name, "HomeViewController", "HomeViewController should be public and final")
        
        // Test using and() for custom predicates
        let viewControllersWithViewModel = scope.classes()
            .withNameSuffix("ViewController")
            .and { $0.hasProperty(named: "viewModel") }
        
        XCTAssertEqual(viewControllersWithViewModel.count, 1, "Should find 1 view controller with viewModel property")
        XCTAssertEqual(viewControllersWithViewModel.first?.name, "HomeViewController", 
                      "HomeViewController should have viewModel property")
        
        // Test matching with custom predicate
        let classesWithStaticProperty = scope.classes().matching { classDecl in
            classDecl.properties.contains { property in
                property.hasModifier(.static)
            }
        }
        
        XCTAssertTrue(classesWithStaticProperty.count > 0, "Should find classes with static properties")
        XCTAssertTrue(classesWithStaticProperty.contains { $0.name == "ConfigurationManager" }, 
                     "ConfigurationManager should have static properties")
        
        // Combined filter across multiple declaration types
        let allNetworkRelated = scope.declarations()
            .withNameContaining("Network")
            .inFilePathContaining("Classes.swift")
        
        XCTAssertTrue(allNetworkRelated.count > 0, "Should find network-related declarations in Classes.swift")
        XCTAssertTrue(allNetworkRelated.contains { $0.name == "NetworkService" }, 
                     "Should find NetworkService in Classes.swift")
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCases() {
        let testFilesDirectory = makeSUT()
        defer {
            cleanup(testFilesDirectory)
        }

        let scope = Conformant.scopeFromDirectory(testFilesDirectory)

        // Test empty collections
        let nonExistentPrefixClasses = scope.classes().withNamePrefix("NonExistent")
        XCTAssertEqual(nonExistentPrefixClasses.count, 0, "Should find 0 classes with non-existent prefix")
        
        // Test assertions on empty collections
        let emptyAssertAll = nonExistentPrefixClasses.assertEmpty()
        XCTAssertTrue(emptyAssertAll, "assertEmpty on empty collection should return true")


        // Test invalid regex
        let invalidRegexMatches = scope.declarations().withNameMatching("[")
        XCTAssertEqual(invalidRegexMatches.count, 0, "Invalid regex should return empty collection")
        
        // Test case sensitivity
        let caseInsensitiveMatch = scope.declarations().matching { $0.name == "homeviewcontroller" }
        XCTAssertEqual(caseInsensitiveMatch.count, 0, "Case-sensitive match should find 0 results")
        
        let caseCorrectMatch = scope.declarations().matching { $0.name == "HomeViewController" }
        XCTAssertEqual(caseCorrectMatch.count, 1, "Correct case match should find 1 result")
        
        // Test non-existent properties/methods
        let nonExistentPropertyClasses = scope.classes().havingProperty(named: "nonExistentProperty")
        XCTAssertEqual(nonExistentPropertyClasses.count, 0, "Should find 0 classes with non-existent property")
        
        let nonExistentMethodClasses = scope.classes().havingMethod(named: "nonExistentMethod")
        XCTAssertEqual(nonExistentMethodClasses.count, 0, "Should find 0 classes with non-existent method")
    }
}

extension FilteringAPITests {
    func makeSUT() -> String {
        let testFilesDirectory = NSTemporaryDirectory() + "FilteringAPITests_" + UUID().uuidString

        do {
            try FileManager.default.createDirectory(atPath: testFilesDirectory, withIntermediateDirectories: true)

            // Create test files
            try createClassesFile(testFilesDirectory)
            try createStructsFile(testFilesDirectory)
            try createProtocolsFile(testFilesDirectory)
            try createEnumsFile(testFilesDirectory)
            try createFunctionsFile(testFilesDirectory)
            try createModelsFile(testFilesDirectory)
            try createImportsFile(testFilesDirectory)
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }

        return testFilesDirectory
    }

    private func cleanup(_ testFilesDirectory: String) {
        try? FileManager.default.removeItem(atPath: testFilesDirectory)
    }

    private func createClassesFile(_ testFilesDirectory: String) throws {
        let classesContent = """
        import Foundation
        import UIKit
        
        // Base class
        open class BaseViewController: UIViewController {
            public var isLoading: Bool = false
            
            open override func viewDidLoad() {
                super.viewDidLoad()
                setupViews()
            }
            
            private func setupViews() {
                // Base setup
            }
        }
        
        // Standard view controller
        @available(iOS 13.0, *)
        public final class HomeViewController: BaseViewController {
            private let viewModel: HomeViewModel
            
            public init(viewModel: HomeViewModel) {
                self.viewModel = viewModel
                super.init(nibName: nil, bundle: nil)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            public override func viewDidLoad() {
                super.viewDidLoad()
                bindViewModel()
            }
            
            private func bindViewModel() {
                viewModel.loadData()
            }
        }
        
        // Service class
        public class NetworkService {
            private let session: URLSession
            
            public init(session: URLSession = .shared) {
                self.session = session
            }
            
            public func fetch<T: Decodable>(from url: URL) async throws -> T {
                let (data, _) = try await session.data(from: url)
                return try JSONDecoder().decode(T.self, from: data)
            }
        }
        
        // Non-final class
        public class ConfigurationManager {
            public static let shared = ConfigurationManager()
            
            private var settings: [String: Any] = [:]
            
            private init() {}
            
            public func getSetting<T>(for key: String) -> T? {
                return settings[key] as? T
            }
            
            public func setSetting<T>(value: T, for key: String) {
                settings[key] = value
            }
        }
        """

        try classesContent.write(toFile: testFilesDirectory + "/Classes.swift", atomically: true, encoding: .utf8)
    }

    private func createStructsFile(_ testFilesDirectory: String) throws {
        let structsContent = """
        import Foundation
        
        // Model struct
        public struct User: Codable, Equatable, Identifiable {
            public let id: UUID
            public var firstName: String
            public var lastName: String
            public var email: String?
            
            public var fullName: String {
                return "\\(firstName) \\(lastName)"
            }
            
            public init(id: UUID = UUID(), firstName: String, lastName: String, email: String? = nil) {
                self.id = id
                self.firstName = firstName
                self.lastName = lastName
                self.email = email
            }
            
            public static func == (lhs: User, rhs: User) -> Bool {
                return lhs.id == rhs.id
            }
        }
        
        // View model struct
        public struct ProductViewModel {
            public let id: String
            public let name: String
            public let price: Double
            public let imageURL: URL?
            
            public var formattedPrice: String {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                return formatter.string(from: NSNumber(value: price)) ?? "$\\(price)"
            }
            
            public init(id: String, name: String, price: Double, imageURL: URL? = nil) {
                self.id = id
                self.name = name
                self.price = price
                self.imageURL = imageURL
            }
        }
        
        // Configuration struct
        public struct NetworkConfiguration {
            public let baseURL: URL
            public var headers: [String: String]
            public var timeout: TimeInterval
            
            public init(baseURL: URL, headers: [String: String] = [:], timeout: TimeInterval = 30.0) {
                self.baseURL = baseURL
                self.headers = headers
                self.timeout = timeout
            }
            
            public func withAdditionalHeader(name: String, value: String) -> NetworkConfiguration {
                var newHeaders = headers
                newHeaders[name] = value
                return NetworkConfiguration(baseURL: baseURL, headers: newHeaders, timeout: timeout)
            }
        }
        """

        try structsContent.write(toFile: testFilesDirectory + "/Structs.swift", atomically: true, encoding: .utf8)
    }

    private func createProtocolsFile(_ testFilesDirectory: String) throws {
        let protocolsContent = """
        import Foundation
        
        // Service protocol
        public protocol DataService {
            associatedtype DataType
            
            func fetchData() async throws -> [DataType]
            func saveData(_ data: DataType) async throws
            func deleteData(id: String) async throws
        }
        
        // Repository protocol
        public protocol Repository {
            associatedtype Entity
            associatedtype ID
            
            func fetch(id: ID) async throws -> Entity
            func save(_ entity: Entity) async throws
            func delete(id: ID) async throws
            func listAll() async throws -> [Entity]
        }
        
        // Protocol inheritance
        public protocol UserRepository: Repository where Entity == User, ID == UUID {
            func fetchByEmail(_ email: String) async throws -> User?
        }
        
        // View model protocol
        public protocol ViewModel {
            var isLoading: Bool { get set }
            var error: Error? { get set }
            
            func loadData() async
            func refresh() async
        }
        
        // Delegate protocol
        public protocol HomeViewControllerDelegate: AnyObject {
            func homeViewControllerDidSelectUser(_ user: User)
            func homeViewControllerDidRequestLogout()
        }
        """

        try protocolsContent.write(toFile: testFilesDirectory + "/Protocols.swift", atomically: true, encoding: .utf8)
    }

    private func createEnumsFile(_ testFilesDirectory: String) throws {
        let enumsContent = """
        import Foundation
        
        // Simple enum
        public enum Theme {
            case light
            case dark
            case system
            
            public var isDarkMode: Bool {
                switch self {
                case .light: return false
                case .dark: return true
                case .system: return true // Assume system is dark for simplicity
                }
            }
        }
        
        // Raw value enum
        public enum ApiEndpoint: String {
            case users = "/api/users"
            case products = "/api/products"
            case orders = "/api/orders"
            
            public var path: String {
                return self.rawValue
            }
            
            public var requiresAuth: Bool {
                return self != .users
            }
        }
        
        // Associated value enum
        public enum NetworkError: Error, Equatable {
            case badRequest(message: String)
            case unauthorized
            case notFound
            case serverError(code: Int)
            
            public var message: String {
                switch self {
                case .badRequest(let message): return "Bad request: \\(message)"
                case .unauthorized: return "Unauthorized access"
                case .notFound: return "Resource not found"
                case .serverError(let code): return "Server error: \\(code)"
                }
            }
            
            public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
                switch (lhs, rhs) {
                case (.badRequest(let lhsMsg), .badRequest(let rhsMsg)): return lhsMsg == rhsMsg
                case (.unauthorized, .unauthorized): return true
                case (.notFound, .notFound): return true
                case (.serverError(let lhsCode), .serverError(let rhsCode)): return lhsCode == rhsCode
                default: return false
                }
            }
        }
        
        // CaseIterable enum
        public enum UserRole: String, CaseIterable {
            case admin
            case editor
            case viewer
            case guest
            
            public var canEdit: Bool {
                return self == .admin || self == .editor
            }
        }
        """

        try enumsContent.write(toFile: testFilesDirectory + "/Enums.swift", atomically: true, encoding: .utf8)
    }

    private func createFunctionsFile(_ testFilesDirectory: String) throws {
        let functionsContent = """
        import Foundation
        
        // Top-level functions
        
        // Simple function
        public func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            return formatter.string(from: NSNumber(value: amount)) ?? "\\(amount)"
        }
        
        // Async function
        public func fetchData(from url: URL) async throws -> Data {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
        
        // Function with multiple parameters
        public func calculateDistance(from point1: (x: Double, y: Double), to point2: (x: Double, y: Double)) -> Double {
            let xDist = point2.x - point1.x
            let yDist = point2.y - point1.y
            return sqrt(xDist * xDist + yDist * yDist)
        }
        
        // Generic function
        public func findElement<T: Equatable>(_ element: T, in array: [T]) -> Int? {
            return array.firstIndex(of: element)
        }
        
        // Function with no return value
        public func logMessage(_ message: String, level: LogLevel = .info) {
            print("[\\(level)]: \\(message)")
        }
        
        // Helper enum for above function
        public enum LogLevel: String {
            case debug
            case info
            case warning
            case error
        }
        """

        try functionsContent.write(toFile: testFilesDirectory + "/Functions.swift", atomically: true, encoding: .utf8)
    }

    private func createModelsFile(_ testFilesDirectory: String) throws {
        let modelsContent = """
        import Foundation
        
        // Model with properties
        public struct Product {
            // Stored properties with initial values
            public let id: String = UUID().uuidString
            public var name: String
            public var price: Double
            public var isAvailable: Bool = true
            
            // Computed properties
            public var formattedPrice: String {
                return "$\\(String(format: "%.2f", price))"
            }
            
            public var taxIncludedPrice: Double {
                return price * 1.08 // Assume 8% tax
            }
            
            // Stored property without initial value
            public var description: String?
            
            // Type property
            public static let defaultPrice: Double = 9.99
            
            public init(name: String, price: Double) {
                self.name = name
                self.price = price
            }
        }
        
        // Class with various property types
        public class UserSettings {
            // Lazy property
            public lazy var defaultUser: User = {
                return User(firstName: "Default", lastName: "User")
            }()
            
            // Constant property
            public let appVersion: String = "1.0.0"
            
            // Variable property with private setter
            private(set) public var lastLoginDate: Date?
            
            // Property with observer
            public var isDarkModeEnabled: Bool = false {
                didSet {
                    UserDefaults.standard.set(isDarkModeEnabled, forKey: "isDarkModeEnabled")
                }
            }
            
            // Private properties
            private var cachedSettings: [String: Any] = [:]
            
            public init() {
                // Load settings
            }
            
            public func updateLastLoginDate() {
                lastLoginDate = Date()
            }
        }
        """

        try modelsContent.write(toFile: testFilesDirectory + "/Models.swift", atomically: true, encoding: .utf8)
    }

    private func createImportsFile(_ testFilesDirectory: String) throws {
        // Create multiple files with different import patterns

        // File with Apple framework imports
        let appleImportsContent = """
        import Foundation
        import UIKit
        import SwiftUI
        import CoreData
        
        // Simple class to make the file valid
        public class UIManager {
            public static let shared = UIManager()
            
            private init() {}
            
            public func setupUI() {
                // Implementation
            }
        }
        """

        // File with third-party imports
        let thirdPartyImportsContent = """
        import Foundation
        import Alamofire
        import SnapKit
        import RxSwift
        import Kingfisher
        
        // Simple class to make the file valid
        public class NetworkManager {
            public static let shared = NetworkManager()
            
            private init() {}
            
            public func setupNetwork() {
                // Implementation
            }
        }
        """

        // File with submodule imports
        let submoduleImportsContent = """
        import Foundation
        import UIKit.UITableView
        import CoreData.NSManagedObject
        
        // Simple class to make the file valid
        public class DataManager {
            public static let shared = DataManager()
            
            private init() {}
            
            public func setupData() {
                // Implementation
            }
        }
        """

        try appleImportsContent.write(toFile: testFilesDirectory + "/AppleImports.swift", atomically: true, encoding: .utf8)
        try thirdPartyImportsContent.write(toFile: testFilesDirectory + "/ThirdPartyImports.swift", atomically: true, encoding: .utf8)
        try submoduleImportsContent.write(toFile: testFilesDirectory + "/SubmoduleImports.swift", atomically: true, encoding: .utf8)
    }
}
