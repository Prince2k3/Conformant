import Foundation

// MARK: - Dependency Checking API

extension Collection where Element == SwiftDependency {
    public func containsDependency(name: String, kind: DependencyKind? = nil) -> Bool {
        return self.contains { dependency in
            let nameMatch = dependency.name == name
            let kindMatch = (kind == nil) || (dependency.kind == kind)
            return nameMatch && kindMatch
        }
    }

    public func containsDependency(kind: DependencyKind) -> Bool {
        return self.contains { $0.kind == kind }
    }
}

// MARK: - Enhanced Filtering API

extension Collection where Element: SwiftDeclaration {

    // MARK: - Name Filtering

    /// Filter declarations by name suffix
    public func withNameSuffix(_ suffix: String) -> [Element] {
        return self.filter { $0.name.hasSuffix(suffix) }

    }

    /// Filter declarations by name prefix
    public func withNamePrefix(_ prefix: String) -> [Element] {
        return self.filter { $0.name.hasPrefix(prefix) }
    }

    /// Filter declarations by containing name
    public func withNameContaining(_ substring: String) -> [Element] {
        return self.filter { $0.name.contains(substring) }
    }

    /// Filter declarations by name matching regex
    public func withNameMatching(_ pattern: String) -> [Element] {
        do {
            let regex = try Regex(pattern)
            return self.filter { $0.name.contains(regex) }
        } catch {
            print("Invalid regex pattern: \(pattern) - \(error)")
            return []
        }
    }

    /// Filter declarations by exact name
    public func withName(_ name: String) -> [Element] {
        return self.filter { $0.name == name }
    }

    /// Filter declarations by names in the provided array
    public func withNames(_ names: [String]) -> [Element] {
        return self.filter { names.contains($0.name) }
    }

    // MARK: - Modifier Filtering

    /// Filter declarations by having a specific modifier
    public func withModifier(_ modifier: SwiftModifier) -> [Element] {
        return self.filter { $0.hasModifier(modifier) }
    }

    /// Filter declarations by having any of the specified modifiers
    public func withAnyModifier(_ modifiers: SwiftModifier...) -> [Element] {
        return self.filter { declaration in
            modifiers.contains { declaration.hasModifier($0) }
        }
    }

    /// Filter declarations by having all of the specified modifiers
    public func withAllModifiers(_ modifiers: SwiftModifier...) -> [Element] {
        return self.filter { declaration in
            modifiers.allSatisfy { declaration.hasModifier($0) }
        }
    }

    /// Filter declarations by not having a specific modifier
    public func withoutModifier(_ modifier: SwiftModifier) -> [Element] {
        return self.filter { !$0.hasModifier(modifier) }
    }

    /// Filter declarations by not having any of the specified modifiers
    public func withoutAnyModifier(_ modifiers: SwiftModifier...) -> [Element] {
        return self.filter { declaration in
            !modifiers.contains { declaration.hasModifier($0) }
        }
    }

    // MARK: - Annotation Filtering

    /// Filter declarations by having a specific annotation
    public func withAnnotation(named name: String) -> [Element] {
        return self.filter { $0.hasAnnotation(named: name) }
    }

    /// Filter declarations by having any of the specified annotations
    public func withAnyAnnotation(named names: String...) -> [Element] {
        return self.filter { declaration in
            names.contains { declaration.hasAnnotation(named: $0) }
        }
    }

    /// Filter declarations by having all of the specified annotations
    public func withAllAnnotations(named names: String...) -> [Element] {
        return self.filter { declaration in
            names.allSatisfy { declaration.hasAnnotation(named: $0) }
        }
    }

    /// Filter declarations by not having a specific annotation
    public func withoutAnnotation(named name: String) -> [Element] {
        return self.filter { !$0.hasAnnotation(named: name) }
    }

    // MARK: - Location Filtering

    /// Filter declarations by residing in a specific file
    public func inFile(_ filePath: String) -> [Element] {
        return self.filter { $0.filePath == filePath }
    }

    /// Filter declarations by residing in a file whose path contains the given string
    public func inFilePathContaining(_ substring: String) -> [Element] {
        return self.filter { $0.filePath.contains(substring) }
    }

    /// Filter declarations by residing in a package matching the pattern
    public func inPackage(_ packagePattern: String) -> [Element] {
        return self.filter { $0.resideInPackage(packagePattern) }
    }

    // MARK: - Dependency Filtering

    /// Filter declarations that depend on a specific type
    public func dependingOn(type: String) -> [Element] {
        return self.filter { declaration in
            declaration.dependencies.contains { $0.name == type }
        }
    }

    /// Filter declarations that depend on a specific module via imports
    public func dependingOnModule(_ moduleName: String) -> [Element] {
        return self.filter { declaration in
            declaration.dependencies.contains { $0.name == moduleName && $0.kind == .import }
        }
    }

    /// Filter declarations that have any type dependency
    public func havingDependencies() -> [Element] {
        return self.filter { !$0.dependencies.isEmpty }
    }

    // MARK: - Combined Filtering

    /// Allows for combining multiple filters with AND logic
    public func and(_ predicate: @escaping (Element) -> Bool) -> [Element] {
        return self.filter(predicate)
    }

    /// Apply a custom filter
    public func matching(_ predicate: @escaping (Element) -> Bool) -> [Element] {
        return self.filter(predicate)
    }
}

// MARK: - Class-Specific Filtering

extension Collection where Element == SwiftClassDeclaration {
    /// Filter classes that extend a specific superclass
    public func extending(class superClassName: String) -> [Element] {
        return self.filter { $0.extends(class: superClassName) }
    }

    /// Filter classes that implement a specific protocol
    public func implementing(protocol protocolName: String) -> [Element] {
        return self.filter { $0.implements(protocol: protocolName) }
    }

    /// Filter classes that implement any of the specified protocols
    public func implementingAny(protocols protocolNames: String...) -> [Element] {
        return self.filter { classDecl in
            protocolNames.contains { classDecl.implements(protocol: $0) }
        }
    }

    /// Filter classes that implement all of the specified protocols
    public func implementingAll(protocols protocolNames: String...) -> [Element] {
        return self.filter { classDecl in
            protocolNames.allSatisfy { classDecl.implements(protocol: $0) }
        }
    }

    /// Filter classes that have a specific method
    public func havingMethod(named methodName: String) -> [Element] {
        return self.filter { $0.hasMethod(named: methodName) }
    }

    /// Filter classes that have a specific property
    public func havingProperty(named propertyName: String) -> [Element] {
        return self.filter { $0.hasProperty(named: propertyName) }
    }

    /// Filter classes that are subclasses (not final)
    public func subclassable() -> [Element] {
        return self.filter { !$0.hasModifier(.final) }
    }

    /// Filter final classes
    public func final() -> [Element] {
        return self.filter { $0.hasModifier(.final) }
    }
}

// MARK: - Struct-Specific Filtering

extension Collection where Element == SwiftStructDeclaration {
    /// Filter structs that implement a specific protocol
    public func implementing(protocol protocolName: String) -> [Element] {
        return self.filter { $0.implements(protocol: protocolName) }
    }

    /// Filter structs that implement any of the specified protocols
    public func implementingAny(protocols protocolNames: String...) -> [Element] {
        return self.filter { structDecl in
            protocolNames.contains { structDecl.implements(protocol: $0) }
        }
    }

    /// Filter structs that implement all of the specified protocols
    public func implementingAll(protocols protocolNames: String...) -> [Element] {
        return self.filter { structDecl in
            protocolNames.allSatisfy { structDecl.implements(protocol: $0) }
        }
    }

    /// Filter structs that have a specific method
    public func havingMethod(named methodName: String) -> [Element] {
        return self.filter { $0.hasMethod(named: methodName) }
    }

    /// Filter structs that have a specific property
    public func havingProperty(named propertyName: String) -> [Element] {
        return self.filter { $0.hasProperty(named: propertyName) }
    }
}

// MARK: - Protocol-Specific Filtering

extension Collection where Element == SwiftProtocolDeclaration {
    /// Filter protocols that inherit from a specific protocol
    public func inheriting(protocol protocolName: String) -> [Element] {
        return self.filter { $0.inherits(protocol: protocolName) }
    }

    /// Filter protocols that require a specific method
    public func requiringMethod(named methodName: String) -> [Element] {
        return self.filter { protocolDecl in
            protocolDecl.methodRequirements.contains { $0.name == methodName }
        }
    }

    /// Filter protocols that require a specific property
    public func requiringProperty(named propertyName: String) -> [Element] {
        return self.filter { protocolDecl in
            protocolDecl.propertyRequirements.contains { $0.name == propertyName }
        }
    }
}

// MARK: - Function-Specific Filtering

extension Collection where Element == SwiftFunctionDeclaration {
    /// Filter functions that return a specific type
    public func returningType(_ typeName: String) -> [Element] {
        return self.filter { $0.returnType == typeName }
    }

    /// Filter functions that return any type (not void)
    public func returningAnyType() -> [Element] {
        return self.filter { $0.hasReturnType() }
    }

    /// Filter functions that return void
    public func returningVoid() -> [Element] {
        return self.filter { !$0.hasReturnType() }
    }

    /// Filter functions that have a specific parameter
    public func havingParameter(named parameterName: String) -> [Element] {
        return self.filter { $0.hasParameter(named: parameterName) }
    }

    /// Filter functions with a specific number of parameters
    public func withParameterCount(_ count: Int) -> [Element] {
        return self.filter { $0.parameters.count == count }
    }

    /// Filter functions with at least a certain number of parameters
    public func withMinParameterCount(_ minCount: Int) -> [Element] {
        return self.filter { $0.parameters.count >= minCount }
    }

    /// Filter async functions
    public func async() -> [Element] {
        return self.filter { $0.isAsync }
    }

    /// Filter throwing functions
    public func throwing() -> [Element] {
        return self.filter { $0.isThrowing }
    }

    /// Filter rethrowing functions
    public func rethrowing() -> [Element] {
        return self.filter { $0.effectSpecifiers.isRethrows }
    }
}

// MARK: - Property-Specific Filtering

extension Collection where Element == SwiftPropertyDeclaration {
    /// Filter properties of a specific type
    public func ofType(_ typeName: String) -> [Element] {
        return self.filter { $0.type == typeName }
    }

    /// Filter computed properties
    public func computed() -> [Element] {
        return self.filter { $0.isComputed }
    }

    /// Filter stored properties
    public func stored() -> [Element] {
        return self.filter { !$0.isComputed }
    }

    /// Filter properties with default values
    public func withInitialValue() -> [Element] {
        return self.filter { $0.initialValue != nil }
    }

    /// Filter properties without default values
    public func withoutInitialValue() -> [Element] {
        return self.filter { $0.initialValue == nil }
    }
}

// MARK: - Enum-Specific Filtering

extension Collection where Element == SwiftEnumDeclaration {
    /// Filter enums that implement a specific protocol
    public func implementing(protocol protocolName: String) -> [Element] {
        return self.filter { $0.implements(protocol: protocolName) }
    }

    /// Filter enums with a specific raw type
    public func withRawType(_ typeName: String) -> [Element] {
        return self.filter { $0.rawType == typeName }
    }

    /// Filter enums that have a specific case
    public func havingCase(named caseName: String) -> [Element] {
        return self.filter { enumDecl in
            enumDecl.cases.contains { $0.name == caseName }
        }
    }

    /// Filter enums with associated values
    public func withAssociatedValues() -> [Element] {
        return self.filter { enumDecl in
            enumDecl.cases.contains { $0.associatedValues != nil && !($0.associatedValues?.isEmpty ?? true) }
        }
    }

    /// Filter enums with raw values
    public func withRawValues() -> [Element] {
        return self.filter { enumDecl in
            enumDecl.cases.contains { $0.rawValue != nil }
        }
    }
}

// MARK: - Import-Specific Filtering

extension Collection where Element == SwiftImportDeclaration {
    /// Filter imports by module name
    public func ofModule(_ moduleName: String) -> [Element] {
        return self.filter { $0.name == moduleName }
    }

    /// Filter imports by import kind
    public func ofKind(_ kind: SwiftImportDeclaration.ImportKind) -> [Element] {
        return self.filter { $0.kind == kind }
    }

    /// Filter imports that include a specific type
    public func includingType(_ typeName: String) -> [Element] {
        return self.filter { $0.includesType(named: typeName) }
    }

    /// Filter imports from Apple frameworks
    public func fromAppleFrameworks() -> [Element] {
        let appleFrameworks = [
            "UIKit", "SwiftUI", "Foundation", "CoreData", "CoreGraphics",
            "CoreLocation", "MapKit", "AVFoundation", "CoreBluetooth",
            "CoreImage", "CoreML", "CloudKit", "GameKit", "HealthKit",
            "HomeKit", "ARKit", "SceneKit", "SpriteKit", "WatchKit",
            "WebKit", "StoreKit", "SafariServices", "PhotosUI", "Network",
            "Metal", "MetalKit", "MetricKit", "ModelIO", "MultipeerConnectivity",
            "GameController", "GameplayKit", "EventKit", "ExternalAccessory",
            "CoreMotion", "CoreMedia", "CoreAudio", "CoreAnimation"
        ]

        return self.filter { appleFrameworks.contains($0.name) }
    }

    /// Filter imports from third-party libraries (non-Apple frameworks)
    public func fromThirdPartyLibraries() -> [Element] {
        let appleFrameworks = [
            "UIKit", "SwiftUI", "Foundation", "CoreData", "CoreGraphics",
            "CoreLocation", "MapKit", "AVFoundation", "CoreBluetooth",
            "CoreImage", "CoreML", "CloudKit", "GameKit", "HealthKit",
            "HomeKit", "ARKit", "SceneKit", "SpriteKit", "WatchKit",
            "WebKit", "StoreKit", "SafariServices", "PhotosUI", "Network",
            "Metal", "MetalKit", "MetricKit", "ModelIO", "MultipeerConnectivity",
            "GameController", "GameplayKit", "EventKit", "ExternalAccessory",
            "CoreMotion", "CoreMedia", "CoreAudio", "CoreAnimation"
        ]

        // Also consider standard library/Swift modules as not third-party
        let swiftModules = ["Swift", "Combine", "Dispatch", "XCTest"]
        let allInternalModules = appleFrameworks + swiftModules

        return self.filter { !allInternalModules.contains($0.name) }
    }

    /// Filter imports with submodules
    public func withSubmodules() -> [Element] {
        return self.filter { !$0.submodules.isEmpty }
    }
}
