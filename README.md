# Conformant

Conformant is a tool that leverages Swift’s [swift-syntax](https://github.com/swiftlang/swift-syntax) to automate testing and enforce code structure consistency and architectural rules in your Swift projects.  Heavily inspired by [Konsist](https://docs.konsist.lemonappdev.com) and [ArchUnit](https://www.archunit.org/userguide/html/000_Index.html#_freezing_arch_rules)

## Features

- **Complete Declaration Coverage**: Every form in the Swift grammar is extracted: classes, structs, enums, protocols, actors, extensions, typealiases, functions, properties, initializers, deinitializers, subscripts, associated types, macros, operators, and precedence groups. Nested types are collected in their own right, under a qualified name (`Outer.Inner`).
- **Architectural Rules**: Define and enforce architectural boundaries between different layers of your application. MVC, MVVM, Clean Architecture, DDD, VIPER and Hexagonal are each [stated as a handful of rules](#stating-a-style-as-rules).
- **Import Analysis**: Track and verify import dependencies between modules. An `import` carries a dependency on the module it names, so a layer defined by module is reached the moment another layer imports it.
- **Dependency Tracking**: Analyze type dependencies across your entire codebase, in signatures *and* bodies, so a type constructed inside a method is as visible to a layer rule as a stored property is.
- **Freezing Rules**: Record existing violations and only report new ones to support gradual architectural improvement.
- **Custom Assertions**: Create custom code quality rules as unit tests.
- **XCTest Integration**: Run consistency checks as part of your test suite.
- **Flexible Layer Definitions**: Define architectural layers using directories, modules, or custom predicates.
- **Stated Build Configuration**: Read every `#if` branch by default, or name the build you mean and read only the branches it compiles.

## Installation

### Swift Package Manager

Add Conformant to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Prince2k3/Conformant.git", from: "0.2.0")
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

Every check starts from a scope, the set of Swift files to analyze.

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

`ScopePolicy` also carries `dependencyDepth`, `ignoresStandardLibraryTypes`, and
`conditionalCompilation`. See [Dependency Analysis](#dependency-analysis) and
[Conditional compilation](#conditional-compilation).

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
            rules.add(presentation.onlyDependsOn(domain, core))
            rules.add(data.onlyDependsOn(domain, core))
            
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
`checkArchitecture`, which returns every failure it found, including problems with the
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

### Choosing a Rule

| Rule | Holds when |
| --- | --- |
| `layer.dependsOnNothing()` | Nothing in the layer names a type from any *other* declared layer. Its own types, and types in no declared layer (the standard library, third-party modules) are fine. |
| `layer.onlyDependsOn(a, b)` | Every dependency that leaves the layer lands in `a` or `b`. The layer's own types are always allowed. |
| `layer.mustNotDependOn(a, b)` | No dependency lands in `a` or `b`. Everything else is allowed, including layers you have not thought about yet. |
| `layer.dependsOn(a)` | Every dependency of the layer lands in `a`, **including dependencies on its own types**. |

`dependsOn` is the strictest of the four and the easiest to misread. It reports every
dependency that is not in the target layer, so a view that refers to another view beside
it is reported. Read it as "depends on this layer and nothing else"; when you mean "may
reach these layers", use `onlyDependsOn`.

Extending a type from another layer is not a violation of any of them: the extended type
is the declaration's own subject rather than something it reached for, so `.extension`
dependencies are excluded from layer rules. Every other kind (`typeUsage`,
`instantiation`, `staticAccess`, `inheritance`, `conformance`, `genericConstraint`,
`import`) is subject to them.

### Stating a Style as Rules

The layers below are written with `Layer(name:modules:predicate:)` so that an `import` of
another layer's module is caught as well as a type reference. A layer defined by
directory alone silently ignores imports.

```swift
func layer(_ name: String, at directory: String? = nil) -> Layer {
    let directory = directory ?? name
    return Layer(name: name, modules: [name], predicate: { $0.filePath.contains("/\(directory)/") })
}
```

**MVC**: the controller is the only part that knows both sides:

```swift
let models = layer("Models"), views = layer("Views"), controllers = layer("Controllers")
rules.add(models.mustNotDependOn(views, controllers))
rules.add(views.mustNotDependOn(models, controllers))
rules.add(controllers.onlyDependsOn(models, views))
```

Catches the view that formats the model itself, and the view that pushes the next screen.

**MVVM**: the view model is testable without a UI, the view holds no decisions:

```swift
let model = layer("Model"), viewModel = layer("ViewModel"), view = layer("View")
rules.add(model.dependsOnNothing())
rules.add(viewModel.mustNotDependOn(view))
rules.add(view.onlyDependsOn(viewModel))
```

Catches the view model that names a row type, and the view that reaches past its view
model into the repository.

**Clean Architecture**: source-level dependencies point inward:

```swift
let entities = layer("Entities"), useCases = layer("UseCases")
let adapters = layer("Adapters"), infrastructure = layer("Infrastructure")
rules.add(entities.dependsOnNothing())
rules.add(useCases.onlyDependsOn(entities))
rules.add(adapters.onlyDependsOn(useCases, entities))
rules.add(infrastructure.onlyDependsOn(adapters, useCases, entities))
```

The inversion is what keeps the middle ring clean: the use case names the port it
declared, and the adapter in the outer ring conforms to it. Catches the use case that
names a concrete gateway, the entity that constructs a store, and the adapter that skips
its use case.

**Hexagonal (ports and adapters)**: the application names only its ports:

```swift
let domain = layer("Domain"), ports = layer("Ports")
let inbound = layer("Inbound", at: "Adapters/Inbound")
let outbound = layer("Outbound", at: "Adapters/Outbound")
rules.add(domain.onlyDependsOn(ports))
rules.add(ports.onlyDependsOn(domain))
rules.add(inbound.onlyDependsOn(ports, domain))
rules.add(outbound.onlyDependsOn(ports, domain))
rules.add(domain.mustNotDependOn(inbound, outbound))
```

Catches the domain that constructs a driven adapter, the driving adapter that calls a
driven one directly, and the port written against one particular adapter.

**VIPER**: five roles and a fixed set of arrows:

```swift
let view = layer("View"), interactor = layer("Interactor"), presenter = layer("Presenter")
let entity = layer("Entity"), router = layer("Router")
rules.add(entity.dependsOnNothing())
rules.add(interactor.onlyDependsOn(entity))
rules.add(presenter.onlyDependsOn(interactor, router, entity))
rules.add(view.onlyDependsOn(presenter, entity))
rules.add(router.onlyDependsOn(view, presenter, interactor))
```

Catches the interactor that holds a view, the view that calls the interactor directly,
and the presenter that builds a screen the router should have built.

**DDD**: tactical layering inside each context, and a boundary between contexts:

```swift
let orderingDomain = layer("OrderingDomain", at: "Ordering/Domain")
let orderingApplication = layer("OrderingApplication", at: "Ordering/Application")
let orderingInfrastructure = layer("OrderingInfrastructure", at: "Ordering/Infrastructure")
let antiCorruption = layer("AntiCorruption", at: "Ordering/AntiCorruption")
let shippingDomain = layer("ShippingDomain", at: "Shipping/Domain")

rules.add(orderingDomain.dependsOnNothing())
rules.add(orderingApplication.onlyDependsOn(orderingDomain))
rules.add(orderingInfrastructure.onlyDependsOn(orderingDomain))
rules.add(shippingDomain.dependsOnNothing())

// Only the anti-corruption layer speaks both vocabularies.
rules.add(orderingApplication.mustNotDependOn(shippingDomain))
rules.add(orderingInfrastructure.mustNotDependOn(shippingDomain))
rules.add(antiCorruption.onlyDependsOn(orderingDomain, shippingDomain))
rules.add(shippingDomain.mustNotDependOn(orderingDomain, orderingApplication))
```

Two contexts model overlapping facts and are meant to stay different. The boundary has to
be asserted from both sides, because a use case that borrows the other context's type
merges the two models just as thoroughly in either direction.

Where the translation happens is a question about the whole scope rather than one layer,
so it is worth asking directly:

```swift
let shippingVocabulary: Set<String> = ["Consignment", "ShippingService"]
let speakers = scope.declarations()
    .filter { !$0.filePath.contains("/Shipping/") }
    .filter { $0.dependencies.contains { shippingVocabulary.contains($0.name) } }
    .map(\.name)

XCTAssertEqual(speakers, ["ShippingBookingAdapter"])
```

Each style above is a runnable suite under
[`Tests/ConformantTests/Architecture/`](Tests/ConformantTests/Architecture). Each writes a
small application in that layout, asserts the clean version passes, then injects one file
per test for the characteristic decay and asserts the declaration, the dependency, and
the dependency kind that get reported.

### Making Sure a Pass Means Something

A rule over a layer that matched no declaration passes, because there was nothing to
contradict it, which is what a mistyped directory name produces. The scope is guarded
against being empty; a layer is not. Assert it where it matters:

```swift
let declarations = scope.declarations()
for layer in [domain, data, presentation] {
    XCTAssertFalse(
        declarations.filter { layer.resideIn($0) }.isEmpty,
        "Layer '\(layer.name)' matched no declarations, so every rule about it passes vacuously"
    )
}
```

Two more passes worth distrusting: a scope built with `.signatures` depth records no body
dependencies, so a rule about instantiation has nothing to find; and a rule that only
ever ran against types from no declared layer never had a chance to fail. `checkArchitecture`
reports problems with the scope itself (no files, files that failed to parse)
separately from violations, so those are visible in the result rather than hidden behind
a green run.

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

A layer can be named by the modules that belong to it. `import Networking` is then a
dependency on that layer, reported against the import declaration at its own line:

```swift
// A package target names both a module and the directory its sources live in
let networking = Layer(name: "Networking", packageTarget: "NetworkingModule")

// Several targets in one layer
let uiModules = Layer(name: "UI", packageTargets: ["MyAppUI", "MyAppComponents"])

// Modules that are not targets of this package (a framework, say), with a predicate
// deciding which declarations *reside* in the layer
let platform = Layer(name: "Platform", modules: ["UIKit", "SwiftUI"]) { _ in false }
```

```swift
scope.assertArchitecture { rules in
    let domain = Layer(name: "Domain", directory: "Domain")
    let persistence = Layer(name: "Persistence", modules: ["Persistence"]) { _ in false }
    rules.defineLayer(domain)
    rules.defineLayer(persistence)
    // Fails on `import Persistence` anywhere under Domain/
    rules.add(domain.mustNotDependOn(persistence))
}
```

`import Deep.Nested.Module` depends on `Deep`: a layer is defined by module names, and
the rest of the path is inside the module. The submodule components are still available
on the declaration as `submodules`.

### By File Path Pattern

A layer can be named by where its files live. `identifierPattern` is a regular expression
matched against the full path of each declaration's file:

```swift
let domain = Layer(name: "Domain", identifierPattern: "/Sources/AppDomain/.*\\.swift")
```

Inside these patterns `..` is shorthand for "any run of characters", so a path segment can
be written without regex punctuation:

```swift
// Every file with "Networking" anywhere in its path
let networking = Layer(name: "Networking", identifierPattern: "..Networking..")
```

The same shorthand applies to `resideInPackage(_:)`, which asks the question of a single
declaration:

```swift
let misplaced = scope.classes().filter { $0.resideInPackage("..Domain..") }
```

A pattern that is not a valid regular expression is reported on standard output and
matches nothing, rather than failing the run.

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
dependencies belong to it, not to `Outer`. A rule such as "`Outer` must not depend on
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
| `dependingOn(type:)` | Depends on specific type; a qualified dependency also matches its trailing name, so `URL` finds `Foundation.URL` |
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
| `Foundation.URL` | `Foundation.URL`, one name, not `Foundation` + `URL` |
| `[UserProfile]` | `UserProfile`; the sugar is not an `Array` dependency |
| `[String: UserProfile]` | `String`, `UserProfile` |
| `(Request) -> Response` | `Request`, `Response` |
| `any Sendable` | `Sendable` |
| `Any` | none; `Any` is the empty constraint, not a type |

Generic parameters, `associatedtype` names, and `Self` are placeholders rather than
types, so they are never reported:

```swift
struct Box<Element> {
    var first: Element?          // no dependency; Element is Box's own parameter
    var label: String            // depends on String
}
```

A qualified dependency answers to any suffix of its name that starts at a component
boundary, so a rule can name the type however it is written at the use site:

```swift
scope.structs().dependingOn(type: "Foundation.URL")  // matches
scope.structs().dependingOn(type: "URL")             // also matches
scope.structs().dependingOn(type: "Foundation")      // does not; nothing named it alone
```

### Kinds

Every dependency records *how* the type was reached, so a rule can be as narrow as it
needs to be:

| Kind | Written as |
|---|---|
| `.inheritance` | `final class Cache: BaseCache` |
| `.conformance` | `struct Money: Hashable` |
| `.typeUsage` | a type written down: a parameter, return type, property annotation, alias, cast |
| `.instantiation` | a type constructed in a body, as in `UserRepository()` |
| `.staticAccess` | a static or class member reached in a body, as in `DatabaseClient.shared` |
| `.genericConstraint` | a bound on a generic parameter, the `Codable` in `func send<T: Codable>(_ value: T)` |
| `.extension` | `extension Array`, the type being extended |
| `.import` | `import Foundation` |

`kind.isSubjectToLayerRules` is what the layer rules ask of each dependency. Every kind
above is `true` except `.extension`, whose subject is the declaration itself rather than
something it reaches out to.

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

The walker is syntactic: it reports what was written, using Swift's own capitalization
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
reference?.moduleQualifier                    // "Foundation", the leftmost component
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

### Conditional compilation

Conformant compiles nothing, so it cannot know which `#if` branches are live. By default
it reads **all** of them: both halves of an `#if canImport(UIKit) / #else` pair appear in
the scope, even though no build ever has both. That is the safe direction: a rule that
checks a branch this build never compiles reports too much, and too much is visible,
while a rule that never saw the branch it was written for passes silently.

When the duplicates get in the way, state the build you mean:

```swift
var policy = ScopePolicy.strict
policy.conditionalCompilation = .activeBranch(
    BuildConfiguration(
        operatingSystem: "iOS",
        architecture: "arm64",
        targetEnvironment: "simulator",
        swiftVersion: "6.0",
        customFlags: ["DEBUG"],
        importableModules: ["UIKit", "Foundation"]
    )
)
let scope = try Conformant.scope(directory: "Sources", policy: policy)
```

`os()`, `arch()`, `targetEnvironment()`, `canImport()`, `swift(>=)`, `compiler(>=)`,
`-D` flags, `true`/`false`, `!`, `&&`, `||`, and parentheses are evaluated. Anything else
(`hasFeature`, `hasAttribute`, `_endian`, and whatever Swift adds next) is undecided.

Every field of `BuildConfiguration` is optional, and **a predicate the configuration
cannot answer keeps its branch**, along with every branch below it. `os(iOS)` against a
configuration with no `operatingSystem` is undecided, not false. So `.activeBranch(_:)`
can only ever drop code the build definitely excludes.

`customFlags` is the one exception: a flag that is not listed reads as *unset* rather
than unknown, because whoever writes the configuration knows the whole `-D` set just as
the compiler does. A misspelled flag therefore drops code that should have been read,
so spell them the way the build does.

### Ordering and determinism

The same files produce the same output every run. Declarations come back in source order
(by file path, then by line and column) rather than grouped by kind, and a declaration's
dependencies are ordered by where they were written and carry no duplicates. This matters
most for [freezing rules](#using-freezing-rules-for-legacy-projects): a baseline is diffed
against the next run, so an order that shifted between runs would read as a change nobody
made.

Files are parsed across all available cores. That is an implementation detail, since the scope
is assembled in path order regardless of which file finishes first, but it is the reason a
large project scans in seconds rather than in minutes.

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
