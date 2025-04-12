# SwiftArch

SwiftArch is a Swift port of the popular Java [ArchUnit](https://www.archunit.org/) library, allowing you to test your architectural rules in Swift projects using a fluent API and integration with XCTest.

## Features

- **Fluent API** for defining architecture rules in a natural, readable way
- **Swift-oriented model** that understands Swift-specific concepts like protocols, structs, enums, and extensions
- **XCTest integration** to run architecture tests alongside your unit and integration tests
- **Comprehensive rule system** to validate dependencies, naming conventions, layer boundaries, and more
- **Customizable and extensible** to support your project's unique architectural requirements

## Installation

### Swift Package Manager

Add SwiftArch to your package dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftArch.git", from: "0.1.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftArch"]
)
```

## Quick Start

### 1. Create an architecture test case

```swift
import XCTest
import SwiftArch

class AppArchitectureTests: ArchitectureTestCase {
    init() {
        super.init(config: ArchitectureTestConfig(
            projectPath: "/path/to/YourApp",
            moduleName: "YourApp"
        ))
    }
    
    func testLayerDependencies() {
        let rule = types()
            .that(resideInModule("Presentation"))
            .should(onlyDependOnTypes(inModules: ["Presentation", "Domain", "Foundation", "UIKit"]))
        
        assertArchitectureRule(rule)
    }
}
```

### 2. Define your architectural rules

SwiftArch provides a rich set of conditions and predicates to define rules that match your architecture:

```swift
// Ensure ViewControllers follow naming convention
let rule = classes()
    .that(haveNameMatching(".*ViewController$"))
    .should(resideInModule("Presentation"))

// Enforce clean architecture boundaries
let rule = types()
    .that(resideInModule("Domain"))
    .shouldNot(dependOnTypesThat(resideInModule("Presentation")))
    
// Ensure proper usage of protocols
let rule = protocols()
    .that(haveNameMatching(".*Repository$"))
    .should(resideInModule("Domain"))
```

### 3. Run the tests

Architecture tests run just like normal XCTest tests - either from Xcode's test navigator or from the command line:

```bash
swift test --filter "AppArchitectureTests"
```

## Core Concepts

### Selection of Components

Start by selecting the components you want to apply rules to:

- `types()` - Select all types (classes, structs, enums, protocols)
- `classes()` - Select only classes
- `structs()` - Select only structs
- `protocols()` - Select only protocols
- `modules()` - Select modules

Then apply filters to narrow down the selection:

```swift
types()
    .that(resideInModule("MyModule"))
    .and(haveNameMatching(".*Service$"))
```

### Conditions

Apply conditions to check architectural properties:

- Location: `resideInModule()`, `resideInPackage()`
- Naming: `haveNameMatching()`
- Type: `beAClass()`, `beAStruct()`, `beAProtocol()`
- Attributes: `haveAttribute()`
- Access control: `haveModifier(.public)`
- Inheritance/Conformance: `beSubtypeOf()`, `conformTo()`

### Rules

Define what the selected components should or should not do:

```swift
// Positive rules
.should(beAStruct())
.should(conformTo("Codable"))
.should(dependencyRule: DependencyRuleBuilder.onlyDependOnTypes(inModules: ["Core", "Foundation"]))

// Negative rules
.shouldNot(beSubtypeOf("NSObject"))
.shouldNot(dependOnTypesThat(resideInModule("UI")))
```

## Extending SwiftArch

SwiftArch is designed to be extensible. You can create custom conditions for your project's specific needs:

```swift
struct HasVIPERSuffix: TypeCondition {
    var description: String { "have a VIPER component suffix (Interactor, Presenter, etc)" }
    
    func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return ["Interactor", "Presenter", "Router", "View", "Entity"]
            .contains { component.name.hasSuffix($0) }
    }
}

// Use your custom condition
let rule = types()
    .that(HasVIPERSuffix())
    .should(resideInPackage("MyApp.VIPER"))
    
assertArchitectureRule(rule)
```

## License

SwiftArch is available under the MIT license. See the LICENSE file for more info.
