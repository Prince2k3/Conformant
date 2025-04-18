# Conformant

Conformant is a powerful static code analyzer for Swift that enables you to enforce code structure consistency and architectural rules in your Swift projects through automated testing.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Features

- **Code Structure Analysis**: Inspect Swift code elements (classes, structs, protocols, enums, etc.) and verify their properties.
- **Architectural Rules**: Define and enforce architectural boundaries between different layers of your application.
- **Import Analysis**: Track and verify import dependencies between modules.
- **Dependency Tracking**: Analyze type dependencies across your entire codebase.
- **Freezing Rules**: Record existing violations and only report new ones to support gradual architectural improvement.
- **Custom Assertions**: Create custom code quality rules as unit tests.
- **XCTest Integration**: Run consistency checks as part of your test suite.
- **Flexible Layer Definitions**: Define architectural layers using directories, modules, or custom predicates.

## Installation

### Swift Package Manager

Add Conformant to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Conformant.git", from: "0.1.0")
]
```

Then add Conformant as a dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["Conformant"]
)
```

### Xcode

1. Go to File > Add Packages...
2. Enter the repository URL: `https://github.com/yourusername/Conformant.git`
3. Select your project and target

## Usage

### Basic Code Structure Validation

```swift
import XCTest
import Conformant

class CodeStructureTests: XCTestCase {
    
    func testViewControllerNaming() {
        // Test that all ViewControllers follow the naming convention
        let scope = SwiftScope.fromProject()
        
        let viewControllers = scope.classes().filter { $0.name.hasSuffix("ViewController") }
        
        XCTAssertTrue(viewControllers.assertTrue { $0.hasMethod(named: "viewDidLoad") },
                      "All ViewControllers should implement viewDidLoad")
    }
    
    func testRepositoryPattern() {
        // Test that repository implementations follow the repository pattern
        let scope = SwiftScope.fromProject()
        
        let repositories = scope.classes().filter { $0.name.hasSuffix("RepositoryImpl") }
        
        XCTAssertTrue(repositories.assertTrue { repository in
            // Should implement a repository protocol
            return repository.protocols.contains { $0.hasSuffix("Repository") }
        }, "All repository implementations should implement a repository protocol")
    }
}
```

### Enforcing Architectural Boundaries

```swift
import XCTest
import Conformant

class ArchitectureTests: XCTestCase {
    
    func testCleanArchitecture() {
        let scope = SwiftScope.fromProject()
        
        let result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            let data = Layer(name: "Data", directory: "Data")
            let core = Layer(name: "Core", directory: "Core")
            
            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(presentation)
            rules.defineLayer(data)
            rules.defineLayer(core)
            
            // Define architecture rules
            rules.add(domain.dependsOnNothing())
            rules.add(presentation.dependsOn(domain))
            rules.add(data.dependsOn(domain))
            
            // More specific rules
            rules.add(presentation.mustNotDependOn(data))
            rules.add(data.mustNotDependOn(presentation))
            
            // Core can be used by any layer but depends on nothing
            rules.add(core.dependsOnNothing())
        }
        
        XCTAssertTrue(result, "Clean architecture rules should pass")
    }
}
```

### Using Freezing Rules for Legacy Projects

```swift
import XCTest
import Conformant

class ArchitectureTests: XCTestCase {
    
    func testArchitectureWithFreezing() {
        let scope = SwiftScope.fromProject()
        
        let result = scope.assertArchitecture { rules in
            // Define layers
            let domain = Layer(name: "Domain", directory: "Domain")
            let presentation = Layer(name: "Presentation", directory: "Presentation")
            let data = Layer(name: "Data", directory: "Data")
            
            // Register layers
            rules.defineLayer(domain)
            rules.defineLayer(presentation)
            rules.defineLayer(data)
            
            // Add freezing rules - will only report new violations
            let domainRule = domain.dependsOnNothing()
            rules.addFreezing(domainRule, toFile: "violations/domain_dependencies.json")
            
            let presentationRule = presentation.onlyDependsOn(domain)
            rules.addFreezing(presentationRule, toFile: "violations/presentation_dependencies.json")
            
            let dataRule = data.onlyDependsOn(domain)
            rules.addFreezing(dataRule, toFile: "violations/data_dependencies.json")
        }
        
        XCTAssertTrue(result, "No new architecture violations should be introduced")
    }
    
    func testFreezingAllRules() {
        let scope = SwiftScope.fromProject()
        
        let result = scope.assertArchitecture { rules in
            // Define layers and rules
            // ...
            
            // Freeze all rules at once
            rules.freezeAllRules(inDirectory: "violations")
        }
        
        XCTAssertTrue(result, "No new architecture violations should be introduced")
    }
}
```

### Analyzing Import Dependencies

```swift
import XCTest
import Conformant

class ImportTests: XCTestCase {
    
    func testUIKitUsage() {
        // Test that UIKit is only imported in approved locations
        let scope = SwiftScope.fromProject()
        
        // Get all files that import UIKit
        let uiKitImports = scope.imports().filter { $0.name == "UIKit" }
        
        // Check that they're only in the UI layer
        XCTAssertTrue(uiKitImports.assertTrue { import in
            import.filePath.contains("/UI/") || import.filePath.contains("/Views/")
        }, "UIKit should only be imported in the UI layer")
    }
    
    func testNoUIKitInDomain() {
        // Test that domain layer doesn't import UI frameworks
        let domainScope = SwiftScope.fromDirectory("Sources/Domain")
        
        // Check for imports of UI frameworks
        let uiImports = domainScope.imports().filter { 
            $0.name == "UIKit" || $0.name == "SwiftUI"
        }
        
        XCTAssertTrue(uiImports.isEmpty, "Domain layer should not import UI frameworks")
    }
}
```

## Defining Layers

Conformant provides multiple ways to define architectural layers:

### By Directory Path

```swift
// Layer containing files in the "Domain" directory
let domain = Layer(name: "Domain", directory: "Domain")
```

### By Module Name

```swift
// Layer representing all imports of the "NetworkingModule"
let networking = Layer(name: "Networking", module: "NetworkingModule")

// Layer representing multiple modules
let uiModules = Layer(name: "UI", modules: ["UIKit", "SwiftUI"])
```

### By Custom Predicate

```swift
// Layer containing all view models
let viewModels = Layer(name: "ViewModels", predicate: { decl in
    decl.name.hasSuffix("ViewModel")
})

// Layer containing all repositories
let repositories = Layer(name: "Repositories", predicate: { decl in
    decl.name.contains("Repository")
})
```

## Assertion API

Conformant provides a powerful assertion API for verifying code structure:

```swift
// Assert that all declarations match a condition
collection.assertTrue { ... }

// Assert that no declarations match a condition
collection.assertFalse { ... }

// Assert that at least one declaration matches a condition
collection.assertAny { ... }

// Assert that no declarations match a condition
collection.assertNone { ... }
```

## Filtering API

Filter declarations based on various criteria:

```swift
// Filter by name suffix
scope.classes().filter { $0.name.hasSuffix("ViewController") }

// Filter by name regex pattern
scope.declarations().withNameMatching(".*Service$")

// Filter by annotation
scope.classes().withAnnotation(named: "available")

// Filter by modifier
scope.declarations().withModifier(.public)
```

## Working with Imports

Analyze and filter import declarations:

```swift
// Get all imports
let allImports = scope.imports()

// Filter imports by module
let foundationImports = scope.imports().ofModule("Foundation")

// Check if any file imports a specific module
let hasUIKit = scope.hasImport(of: "UIKit")
```

## Dependency Analysis

Analyze type dependencies in your codebase:

```swift
// Get all dependencies of a declaration
let dependencies = classDeclaration.dependencies

// Filter by dependency type
let inheritanceDeps = dependencies.filter { $0.kind == .inheritance }
let importDeps = dependencies.filter { $0.kind == .import }
```

## Freezing Architecture Rules

Enable gradual architectural improvement in legacy codebases:

```swift
// Freeze a single rule
let rule = domain.dependsOnNothing()
let frozenRule = rule.freeze(toFile: "violations/domain_violations.json")

// Use a custom matcher for more control
let customMatcher = CustomViolationMatcher()
let frozenWithCustomMatcher = rule.freeze(using: fileStore, matching: customMatcher)

// Create a custom violation store
class DatabaseViolationStore: ViolationStore {
    // Implementation that uses a database instead of files
}
let dbStore = DatabaseViolationStore(connectionString: "...")
let frozenWithCustomStore = rule.freeze(using: dbStore)
```

## Architecture Progress Reports

Generate reports to track your architectural improvement:

```swift
func generateArchitectureReport() {
    // Load violations from all rule files
    let violationFiles = try! FileManager.default.contentsOfDirectory(atPath: "violations")
        .filter { $0.hasSuffix(".json") }
    
    var allViolations: [StoredViolation] = []
    
    for file in violationFiles {
        let store = FileViolationStore(filePath: "violations/\(file)")
        allViolations.append(contentsOf: store.loadViolations())
    }
    
    // Generate report
    print("Architecture Compliance Report")
    print("--------------------------")
    print("Total violations: \(allViolations.count)")
    
    // Group violations by file
    let violationsByFile = Dictionary(grouping: allViolations) { $0.filePath }
    
    print("\nTop 5 files with violations:")
    let sortedFiles = violationsByFile.sorted { $0.value.count > $1.value.count }
    for (file, violations) in sortedFiles.prefix(5) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("  \(fileName): \(violations.count) violations")
    }
    
    // Group violations by rule
    let violationsByRule = Dictionary(grouping: allViolations) { $0.ruleDescription }
    
    print("\nViolations by rule:")
    for (rule, violations) in violationsByRule {
        print("  \(rule): \(violations.count) violations")
    }
}
```

## License

Conformant is available under the Apache License 2.0. See the [LICENSE](LICENSE) file for more info.
