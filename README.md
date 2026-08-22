# Conformant

Conformant is a tool that leverages Swift’s [swift-syntax](https://github.com/swiftlang/swift-syntax) to automate testing and enforce code structure consistency and architectural rules in your Swift projects.  Heavily inspired by [Konsist](https://docs.konsist.lemonappdev.com) and [ArchUnit](https://www.archunit.org/userguide/html/000_Index.html#_freezing_arch_rules)

## Features

- **Complete Declaration Coverage**: Every form in the Swift grammar is extracted — classes, structs, enums, protocols, actors, extensions, typealiases, functions, properties, initializers, deinitializers, subscripts, associated types, macros, operators, and precedence groups. Nested types are collected in their own right, under a qualified name (`Outer.Inner`).
- **Architectural Rules**: Define and enforce architectural boundaries between different layers of your application.
- **Import Analysis**: Track and verify import dependencies between modules.
- **Dependency Tracking**: Analyze type dependencies across your entire codebase — signatures *and* bodies, so a type constructed inside a method is as visible to a layer rule as a stored property is.
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

### Building a Scope

Every check starts from a scope — the set of Swift files to analyze.

```swift
// Everything under the current directory
let scope = try Conformant.scope()

// Everything under a specific directory
let scope = try Conformant.scope(directory: "Sources/Domain")

// A single file
let scope = try Conformant.scope(file: "Sources/Domain/User.swift")
```

These throw rather than returning an empty scope when something is wrong. That matters:
rules evaluated against zero declarations all pass, so a mistyped path would otherwise
turn into a green test run that checked nothing.

`ScopePolicy` controls what counts as "wrong":

| Policy | Missing path | Syntax error | No files found |
|---|---|---|---|
| `.strict` (default) | throws | throws | throws |
| `.warning` | records a diagnostic | keeps the file, records a diagnostic | records a diagnostic |
| `.lenient` | ignored | ignored | ignored |

```swift
// Analyze what parses and inspect the rest, instead of failing outright.
let scope = try Conformant.scope(directory: "Sources", policy: .warning)
if scope.hasSyntaxErrors {
    print(scope.diagnostics.errors.summary())
}
```

Individual reactions can be mixed:

```swift
let policy = ScopePolicy(onSyntaxError: .warn, onUnreadableFile: .fail, onEmptyScope: .fail)
```

`ScopePolicy` also carries `dependencyDepth` and `ignoresStandardLibraryTypes` — see
[Dependency Analysis](#dependency-analysis).

### Basic Code Structure Validation

```swift
import XCTest
import Conformant

class CodeStructureTests: XCTestCase {
    
    func testViewControllerNaming() throws {
        // Test that all ViewControllers follow the naming convention
        let scope = try Conformant.scope()
        
        let viewControllers = scope.classes().withNameSuffix("ViewController")
        
        viewControllers.assertTrue(message: "All ViewControllers should implement viewDidLoad") { $0.hasMethod(named: "viewDidLoad") }
        
    }
    
    func testRepositoryPattern() throws {
        // Test that repository implementations follow the repository pattern
        let scope = try Conformant.scope()
        
        let repositories = scope.classes().withNameSuffix("RepositoryImpl")
        
        repositories.assertTrue(message: "All repository implementations should implement a repository protocol") { repository in
            // Should implement a repository protocol
            return repository.protocols.contains { $0.hasSuffix("Repository") }
        }
    }
}
```

### Enforcing Architectural Boundaries

```swift
import XCTest
import Conformant

class ArchitectureTests: XCTestCase {
    
    func testCleanArchitecture() throws {
        let scope = try Conformant.scope()
        
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

`assertArchitecture` answers yes or no. When you want the detail, use
`checkArchitecture`, which returns every failure it found — including problems with the
scope itself, reported separately so a run that checked nothing is never mistaken for a
run that passed:

```swift
let result = scope.checkArchitecture { rules in /* ... */ }
XCTAssertTrue(result.passed, result.description)
```

Under XCTest, `verifyArchitecture` does the same and reports each failure through
`XCTFail` directly:

```swift
scope.verifyArchitecture { rules in /* ... */ }
```

### Using Freezing Rules for Legacy Projects

```swift
import XCTest
import Conformant

class ArchitectureTests: XCTestCase {
    
    func testArchitectureWithFreezing() throws {
        let scope = try Conformant.scope()
        
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
    
    func testFreezingAllRules() throws {
        let scope = try Conformant.scope()
        
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
    
    func testUIKitUsage() throws {
        // Test that UIKit is only imported in approved locations
        let scope = try Conformant.scope()
        
        // Get all files that import UIKit
        let uiKitImports = scope.imports().withName("UIKit")
        
        // Check that they're only in the UI layer
        uiKitImports.assertTrue(message: "UIKit should only be imported in the UI layer") { import in
            import.filePath.contains("/UI/") || import.filePath.contains("/Views/")
        }
    }
    
    func testNoUIKitInDomain() throws {
        // Test that domain layer doesn't import UI frameworks
        let domainScope = try Conformant.scope(directory: "Sources/Domain")
        
        // Check for imports of UI frameworks
        let uiImports = domainScope.imports().assertEmpty(message: "Domain layer should not import UI frameworks") { 
            $0.name == "UIKit" || $0.name == "SwiftUI"
        }
    }
}
```

## Defining Layers

Layers in Conformant represent logical sections of your architecture. Here are different ways to define layers:

```swift
// Define a layer based on Swift package targets
let domainLayer = Layer(name: "Domain", packageTarget: "MyAppDomain")

// Define a layer with multiple package targets
let uiLayer = Layer(name: "UI", packageTargets: ["MyAppUI", "MyAppComponents"])

// Define a layer using a directory pattern
let utilsLayer = Layer(name: "Utils", directory: "Utilities")

// Define a layer with a custom predicate
let networkLayer = Layer(name: "Network", predicate: { decl in
    decl.name.hasSuffix("Client") || decl.name.hasSuffix("Service")
})
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

### Overview

The Filtering API provides a collection of extension methods on Swift collections that contain SwiftDeclaration objects. These methods allow you to chain filters together to precisely target specific declarations in your codebase.

## Available Filters

### Name-based Filters

| Method | Description |
|--------|-------------|
| `withName(_:)` | Exact name match |
| `withNames(_:)` | Match any name in the provided array |
| `withNameStarting(with:)` | Prefix match |
| `withNameEnding(with:)` | Suffix match |
| `withName(containing:)` | Contains substring |
| `withName(matching:)` | Regex pattern match |

### Modifier Filters

| Method | Description |
|--------|-------------|
| `withModifier(_:)` | Has specific modifier |
| `withAnyModifier(_:)` | Has any of the specified modifiers |
| `withAllModifiers(_:)` | Has all specified modifiers |
| `withoutModifier(_:)` | Doesn't have a specific modifier |
| `withoutAnyModifier(_:)` | Doesn't have any of the specified modifiers |

### Annotation Filters

| Method | Description |
|--------|-------------|
| `withAnnotation(named:)` | Has specific annotation |
| `withAnyAnnotation(named:)` | Has any of the specified annotations |
| `withAllAnnotations(named:)` | Has all specified annotations |
| `withoutAnnotation(named:)` | Doesn't have a specific annotation |

### Location Filters

| Method | Description |
|--------|-------------|
| `inFile(_:)` | In specific file |
| `inFilePath(containing:)` | In file with path containing substring |
| `inPackage(_:)` | In specific package |

### Nesting Filters

| Method | Description |
|--------|-------------|
| `withParent(_:)` | Declared directly inside the named type |
| `withAncestor(_:)` | Declared inside the named type at any depth |
| `nested()` | Declared inside another type |
| `topLevel()` | Declared at file scope |

A nested type is named as it is written from the outside, so `Inner` inside `Outer` is
`Outer.Inner`. Its `simpleName` is `Inner` and its `parentName` is `Outer`. Its
dependencies belong to it, not to `Outer` — a rule such as "`Outer` must not depend on
`UserRepository`" means what it says.

```swift
// Nested types are visible alongside top-level ones
scope.structs()                      // ["Outer", "Outer.Inner"]
scope.nestedTypes()                  // ["Outer.Inner"]
scope.topLevelTypes()                // ["Outer"]
scope.structs().withParent("Outer")  // ["Outer.Inner"]
```

### Dependency Filters

| Method | Description |
|--------|-------------|
| `dependingOn(type:)` | Depends on specific type — a qualified dependency also matches its trailing name, so `URL` finds `Foundation.URL` |
| `dependingOnModule(_:)` | Depends on specific module |
| `havingDependencies()` | Has any dependencies |

### Type-specific Filters

#### Classes

```swift
// Get classes that extend UIViewController
let viewControllers = scope.classes().extending(class: "UIViewController")

// Get classes that have a specific method
let classesWithInit = scope.classes().havingMethod(named: "init")

// Get non-final classes
let subclassableClasses = scope.classes().subclassable()
```

#### Actors

```swift
// Get actors that conform to a protocol
let auditable = scope.actors().implementing(protocol: "Auditable")

// Get @globalActor and distributed actor declarations
let globalActors = scope.actors().globalActors()
let workers = scope.actors().distributed()
```

#### Typealiases and Subscripts

```swift
// Get typealiases whose aliased type mentions a given type
let handlers = scope.typealiases().aliasing("Response")

// Get generic typealiases
let generic = scope.typealiases().generic()

// Get every settable subscript in the scope
let settable = scope.subscripts().settable()
```

#### Structs

```swift
// Get structs that implement Hashable
let hashableStructs = scope.structs().implementing(protocol: "Hashable")

// Get structs with a specific property
let structs = scope.structs().havingProperty(named: "id")
```

#### Protocols

```swift
// Get protocols that inherit from Equatable
let protocols = scope.protocols().inheriting(protocol: "Equatable")

// Get protocols that require a specific method
let protocols = scope.protocols().requiringMethod(named: "isEqual")
```

#### Functions

```swift
// Get functions that return Bool
let boolFunctions = scope.functions().returningType("Bool")

// Get functions with a specific parameter
let idFunctions = scope.functions().havingParameter(named: "id")

// Get async functions
let asyncFunctions = scope.functions().async()
```

#### Properties

```swift
// Get computed properties
let computedProps = scope.properties().computed()

// Get properties of a specific type
let stringProps = scope.properties().ofType("String")
```

#### Enums

```swift
// Get enums with associated values
let enumsWithAssocValues = scope.enums().withAssociatedValues()

// Get enums with a specific raw type
let stringEnums = scope.enums().withRawType("String")
```

#### Imports

```swift
// Get imports from Apple frameworks
let appleImports = scope.imports().fromAppleFrameworks()

// Get imports with submodules
let submoduleImports = scope.imports().withSubmodules()
```

## Combining Filters

You can chain multiple filters together to create complex queries:

```swift
// Get all public classes that inherit from UIViewController and implement Codable
let classes = scope.classes()
    .withModifier(.public)
    .extending(class: "UIViewController")
    .implementing(protocol: "Codable")
```

## Custom Filtering

If you need more advanced filtering, you can use the `matching(_:)` or `and(_:)` methods to provide a custom predicate:

```swift
// Get classes with more than 5 methods
let largeClasses = scope.classes().matching { $0.methods.count > 5 }

// Apply a custom filter to an existing filtered collection
let result = scope.classes().withModifier(.public).and { 
    $0.name.count > 10 && $0.methods.count > 3
}
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

Every declaration records the types it names:

```swift
// Get all dependencies of a declaration
let dependencies = classDeclaration.dependencies

// Filter by dependency type
let inheritanceDeps = dependencies.inheritances()
let importDeps = dependencies.imports()
```

Dependencies come from walking the parsed type syntax, not from splitting the written
text, so what a declaration depends on is what it actually wrote:

| Written | Dependencies |
|---|---|
| `Foundation.URL` | `Foundation.URL` — one name, not `Foundation` + `URL` |
| `[UserProfile]` | `UserProfile` — the sugar is not an `Array` dependency |
| `[String: UserProfile]` | `String`, `UserProfile` |
| `(Request) -> Response` | `Request`, `Response` |
| `any Sendable` | `Sendable` |
| `Any` | none — `Any` is the empty constraint, not a type |

Generic parameters, `associatedtype` names, and `Self` are placeholders rather than
types, so they are never reported:

```swift
struct Box<Element> {
    var first: Element?          // no dependency — Element is Box's own parameter
    var label: String            // depends on String
}
```

A qualified dependency answers to any suffix of its name that starts at a component
boundary, so a rule can name the type however it is written at the use site:

```swift
scope.structs().dependingOn(type: "Foundation.URL")  // matches
scope.structs().dependingOn(type: "URL")             // also matches
scope.structs().dependingOn(type: "Foundation")      // does not — nothing named it alone
```

### Kinds

Every dependency records *how* the type was reached, so a rule can be as narrow as it
needs to be:

| Kind | Written as |
|---|---|
| `.inheritance` | `final class Cache: BaseCache` |
| `.conformance` | `struct Money: Hashable` |
| `.typeUsage` | a type written down — a parameter, return type, property annotation, alias, cast |
| `.instantiation` | a type constructed in a body — `UserRepository()` |
| `.staticAccess` | a static or class member reached in a body — `DatabaseClient.shared` |
| `.genericConstraint` | a bound on a generic parameter — the `Codable` in `func send<T: Codable>(_ value: T)` |
| `.extension` | `extension Array` — the type being extended |
| `.import` | `import Foundation` |

`kind.couplesToType` answers whether a kind names a type the declaration reaches out to,
and is what the layer rules ask of each dependency. Every kind above is `true` except
`.import`, which module rules match by name on their own path, and `.extension`, whose
subject is the declaration itself.

### Signatures and bodies

Bodies are read by default. `func run() { UserRepository().load() }` couples to
`UserRepository` just as firmly as a stored property would, so the body walker reports it:

```swift
final class Controller {
    func run() {
        let repository = UserRepository()   // UserRepository / .instantiation
        DatabaseClient.shared.connect()     // DatabaseClient / .staticAccess
        let cached = value as? CachedUser   // CachedUser    / .typeUsage
    }
}
```

The walker is syntactic — it reports what was written, using Swift's own capitalization
convention to decide what reads as a type. A dotted chain's leading run of capitalized
components is the type and the rest are members, so `DatabaseClient.shared.fetch()` is one
static access on `DatabaseClient` and `Notification.Name.didChange` is one on
`Notification.Name`. A type whose members are capitalized breaks that convention and will
be read as a nested type.

`ScopePolicy.dependencyDepth` turns bodies off:

```swift
var policy = ScopePolicy.strict
policy.dependencyDepth = .signatures        // default is .signaturesAndBodies
```

Like `ignoresStandardLibraryTypes`, this can only make rules easier to satisfy: a class
that touches a forbidden layer only inside a method body passes `mustNotDependOn` once
bodies are hidden. Reach for it when an existing suite needs a staged migration, not as a
default.

### Type references

Each dependency carries a `TypeReference` describing how the type was written:

```swift
let reference = dependency.reference          // TypeReference?
reference?.baseName                           // "URL"
reference?.qualifiedName                      // "Foundation.URL"
reference?.moduleQualifier                    // "Foundation" — leftmost component
reference?.genericArguments                   // nested references, e.g. Result<Data, Error>
reference?.form                               // .plain, .optional, .array, .dictionary,
                                              // .function, .tuple, .existential, .opaque,
                                              // .metatype, .pack, .composition, .suppressed
reference?.isStandardLibraryType              // true for Int, String, Hashable, …
```

### Filtering out the standard library

`ScopePolicy.ignoresStandardLibraryTypes` drops references to standard library types from
every declaration's dependency list. It is **off by default**: removing dependencies can
only make a rule easier to satisfy, and with it on a type whose only dependency is
`String` would pass `dependsOnNothing()`. Turn it on when a rule is about your own
modules and the noise is genuinely in the way:

```swift
var policy = ScopePolicy.strict
policy.ignoresStandardLibraryTypes = true
let scope = try Conformant.scope(directory: "Sources", policy: policy)
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
