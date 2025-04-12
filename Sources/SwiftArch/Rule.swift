//
//  for.swift
//  SwiftArch
//
//  Created by Prince Ugwuh on 4/10/25.
//

import Foundation

// MARK: - Core Rule System

/// The core protocol for architectural rules
public protocol ArchRule {
    /// Description of the rule
    var description: String { get }

    /// Check if the rule is satisfied for the given architecture model
    /// - Parameter target: The architecture model to check against
    /// - Returns: Result containing all violations if the rule is not satisfied
    func check(target: SwiftTarget) -> RuleCheckResult
}

/// Result of checking an architectural rule
public struct RuleCheckResult {
    /// Whether the rule passed (no violations)
    public let passed: Bool

    /// Description of the rule that was checked
    public let ruleDescription: String

    /// List of violations found during rule check
    public let violations: [Violation]

    /// Create a new rule check result
    public init(passed: Bool, ruleDescription: String, violations: [Violation] = []) {
        self.passed = passed
        self.ruleDescription = ruleDescription
        self.violations = violations
    }
}

/// Represents a violation of an architectural rule
public struct Violation {
    /// Description of the violation
    public let description: String

    /// Source component that violated the rule
    public let sourceComponent: String

    /// Target component that was involved in the violation (if applicable)
    public let targetComponent: String?

    /// Location where the violation occurred
    public let location: SourceLocation?

    /// Create a new violation
    public init(
        description: String,
        sourceComponent: String,
        targetComponent: String? = nil,
        location: SourceLocation? = nil
    ) {
        self.description = description
        self.sourceComponent = sourceComponent
        self.targetComponent = targetComponent
        self.location = location
    }
}

// MARK: - Conditions

/// Protocol for conditions that can be applied to architecture components
public protocol Condition<T> {
    associatedtype T

    /// Description of the condition
    var description: String { get }

    /// Check if the condition is satisfied for a given component
    /// - Parameter component: Component to check
    /// - Returns: true if the condition is satisfied, false otherwise
    func isSatisfiedBy(_ component: T) -> Bool
}

/// Protocol for conditions specifically applicable to Swift types
public protocol TypeCondition: Condition<any SwiftType> {}

/// Protocol for conditions specifically applicable to modules
public protocol ModuleCondition: Condition<SwiftModule> {}

/// Protocol for conditions specifically applicable to dependencies
public protocol DependencyCondition: Condition<Dependency> {}

// MARK: - Core Building Blocks for Rules

/// Entry point for defining rules about Swift types
public func types() -> TypesSelectionBuilder {
    return TypesSelectionBuilder()
}

/// Entry point for defining rules about modules
public func modules() -> ModulesSelectionBuilder {
    return ModulesSelectionBuilder()
}

/// Entry point for defining rules about classes specifically
public func classes() -> ClassesSelectionBuilder {
    return ClassesSelectionBuilder()
}

/// Entry point for defining rules about structs specifically
public func structs() -> StructsSelectionBuilder {
    return StructsSelectionBuilder()
}

/// Entry point for defining rules about protocols specifically
public func protocols() -> ProtocolsSelectionBuilder {
    return ProtocolsSelectionBuilder()
}

/// Builder for selecting types to apply rules to
public class TypesSelectionBuilder {
    private var conditions: [any TypeCondition] = []
    private var description: String = "types"

    /// Filter types that satisfy the given condition
    /// - Parameter condition: Condition to apply
    /// - Returns: Builder for further refinement
    public func that(_ condition: any TypeCondition) -> TypesSelectionBuilder {
        conditions.append(condition)
        description += " that \(condition.description)"
        return self
    }

    /// Add an additional condition with 'and'
    public func and(_ condition: any TypeCondition) -> TypesSelectionBuilder {
        return that(condition)
    }

    /// Define what the selected types should satisfy
    /// - Parameter condition: Condition that should be satisfied
    /// - Returns: Architectural rule to check
    public func should(_ condition: any TypeCondition) -> ComposableRule {
        let ruleDescription = "\(description) should \(condition.description)"
        return ComposableRule(
            baseRule: TypeShouldRule(
                selectionConditions: conditions,
                shouldCondition: condition,
                description: ruleDescription
            )
        )
    }

    /// Define what the selected types should not satisfy
    /// - Parameter condition: Condition that should not be satisfied
    /// - Returns: Architectural rule to check
    public func shouldNot(_ condition: any TypeCondition) -> ComposableRule {
        let ruleDescription = "\(description) should not \(condition.description)"
        return ComposableRule(
            baseRule: TypeShouldNotRule(
                selectionConditions: conditions,
                shouldNotCondition: condition,
                description: ruleDescription
            )
        )
    }

    /// Define dependency rules for the selected types
    /// - Parameter dependencyRule: Builder for dependency rules
    /// - Returns: Architectural rule to check
    public func should(dependencyRule builder: DependencyRuleBuilder) -> ComposableRule {
        let dependencyRule = builder.build()
        let ruleDescription = "\(description) should \(dependencyRule.description)"
        return ComposableRule(
            baseRule: TypeDependencyRule(
                selectionConditions: conditions,
                dependencyRule: dependencyRule,
                description: ruleDescription
            )
        )
    }
}

// MARK: - Rule Implementations

/// Rule that allows composition of multiple rules with methods like orShould, andShould
public class ComposableRule: ArchRule {
    private let baseRule: ArchRule
    private var additionalRules: [ArchRule] = []
    private var isOrOperation: Bool = false

    public var description: String {
        var desc = baseRule.description
        for (index, rule) in additionalRules.enumerated() {
            if index == 0 {
                desc += isOrOperation ? " or " : " and "
            } else {
                desc += " and "
            }
            desc += rule.description.replacingOccurrences(of: "types that", with: "")
        }
        return desc
    }

    init(baseRule: ArchRule) {
        self.baseRule = baseRule
    }

    /// Adds an additional condition that should also be satisfied
    /// - Parameter condition: Condition that should be satisfied
    /// - Returns: The composable rule for further chaining
    public func andShould(_ condition: any TypeCondition) -> ComposableRule {
        let ruleDescription = "should \(condition.description)"
        let additionalRule = TypeShouldRule(
            selectionConditions: [], // Empty because selection is handled by base rule
            shouldCondition: condition,
            description: ruleDescription
        )
        additionalRules.append(additionalRule)
        return self
    }

    /// Adds an alternative condition that could be satisfied
    /// - Parameter condition: Condition that should be satisfied
    /// - Returns: The composable rule for further chaining
    public func orShould(_ condition: any TypeCondition) -> ComposableRule {
        isOrOperation = true
        let ruleDescription = "should \(condition.description)"
        let additionalRule = TypeShouldRule(
            selectionConditions: [], // Empty because selection is handled by base rule
            shouldCondition: condition,
            description: ruleDescription
        )
        additionalRules.append(additionalRule)
        return self
    }

    /// Adds an additional condition that should not be satisfied
    /// - Parameter condition: Condition that should not be satisfied
    /// - Returns: The composable rule for further chaining
    public func andShouldNot(_ condition: any TypeCondition) -> ComposableRule {
        let ruleDescription = "should not \(condition.description)"
        let additionalRule = TypeShouldNotRule(
            selectionConditions: [], // Empty because selection is handled by base rule
            shouldNotCondition: condition,
            description: ruleDescription
        )
        additionalRules.append(additionalRule)
        return self
    }

    /// Adds an exception condition to the rule
    /// - Parameter condition: Condition that exempts a component from the rule
    /// - Returns: The composable rule for further chaining
    public func unless(_ condition: any TypeCondition) -> ComposableRule {
        // Create an exception rule
        // In a complete implementation, we'd need to modify how rules are checked to exclude types
        // that satisfy this condition from the violations

        let exceptionDescription = "unless \(condition.description)"
        // Store the exception condition - we'll check it during rule evaluation
        exceptionConditions.append(condition)
        return self
    }

    /// Exception conditions that exempt components from the rule
    private var exceptionConditions: [any TypeCondition] = []

    public func check(target: SwiftTarget) -> RuleCheckResult {
        // Check the base rule first
        let baseResult = baseRule.check(target: target)

        // If there are no additional rules, just filter the results with exceptions
        if additionalRules.isEmpty {
            return applyExceptions(to: baseResult, target: target)
        }

        // Check additional rules
        var allResults = [baseResult]

        for rule in additionalRules {
            allResults.append(rule.check(target: target))
        }

        // For OR operations, the rule passes if any of the checks pass
        if isOrOperation {
            let passed = allResults.contains { $0.passed }
            let violations = passed ? [] : allResults.flatMap { $0.violations }
            let result = RuleCheckResult(passed: passed, ruleDescription: description, violations: violations)
            return applyExceptions(to: result, target: target)
        }
        // For AND operations (default), the rule passes only if all checks pass
        else {
            let passed = allResults.allSatisfy { $0.passed }
            let violations = allResults.flatMap { $0.violations }
            let result = RuleCheckResult(passed: passed, ruleDescription: description, violations: violations)
            return applyExceptions(to: result, target: target)
        }
    }

    /// Apply exception conditions to filter out violations
    /// - Parameters:
    ///   - result: Original rule check result
    ///   - target: The architecture model
    /// - Returns: Filtered rule check result
    private func applyExceptions(to result: RuleCheckResult, target: SwiftTarget) -> RuleCheckResult {
        // If there are no exceptions or no violations, just return the original result
        if exceptionConditions.isEmpty || result.violations.isEmpty {
            return result
        }

        // Get all types from the target
        let allTypes = target.modules.flatMap { $0.types }

        // Create a lookup dictionary for faster type resolution
        let typesByName: [String: any SwiftType] = Dictionary(
            uniqueKeysWithValues: allTypes.map { ($0.fullyQualifiedName, $0) }
        )

        // Filter out violations for types that satisfy any exception condition
        let filteredViolations = result.violations.filter { violation in
            // Find the corresponding type for this violation
            guard let type = typesByName[violation.sourceComponent] else {
                return true // Keep the violation if we can't find the type
            }

            // Check if the type satisfies any exception condition
            return !exceptionConditions.contains { condition in
                condition.isSatisfiedBy(type)
            }
        }

        // Create a new result with the filtered violations
        return RuleCheckResult(
            passed: filteredViolations.isEmpty,
            ruleDescription: result.ruleDescription,
            violations: filteredViolations
        )
    }
}

/// Rule that checks if types satisfy a condition
private class TypeShouldRule: ArchRule {
    private let selectionConditions: [any TypeCondition]
    private let shouldCondition: any TypeCondition
    public let description: String

    init(selectionConditions: [any TypeCondition], shouldCondition: any TypeCondition, description: String) {
        self.selectionConditions = selectionConditions
        self.shouldCondition = shouldCondition
        self.description = description
    }

    public func check(target: SwiftTarget) -> RuleCheckResult {
        var violations: [Violation] = []

        // Collect all types from all modules
        let allTypes = target.modules.flatMap { $0.types }

        // Filter types based on selection conditions
        let selectedTypes = allTypes.filter { type in
            return selectionConditions.allSatisfy { $0.isSatisfiedBy(type) }
        }

        // Check if selected types satisfy the condition
        for type in selectedTypes {
            if !shouldCondition.isSatisfiedBy(type) {
                violations.append(Violation(
                    description: "\(type.fullyQualifiedName) does not \(shouldCondition.description)",
                    sourceComponent: type.fullyQualifiedName,
                    location: type.location
                ))
            }
        }

        return RuleCheckResult(
            passed: violations.isEmpty,
            ruleDescription: description,
            violations: violations
        )
    }
}

/// Rule that checks if types do not satisfy a condition
private class TypeShouldNotRule: ArchRule {
    private let selectionConditions: [any TypeCondition]
    private let shouldNotCondition: any TypeCondition
    public let description: String

    init(selectionConditions: [any TypeCondition], shouldNotCondition: any TypeCondition, description: String) {
        self.selectionConditions = selectionConditions
        self.shouldNotCondition = shouldNotCondition
        self.description = description
    }

    public func check(target: SwiftTarget) -> RuleCheckResult {
        var violations: [Violation] = []

        // Collect all types from all modules
        let allTypes = target.modules.flatMap { $0.types }

        // Filter types based on selection conditions
        let selectedTypes = allTypes.filter { type in
            return selectionConditions.allSatisfy { $0.isSatisfiedBy(type) }
        }

        // Check if selected types do not satisfy the condition
        for type in selectedTypes {
            if shouldNotCondition.isSatisfiedBy(type) {
                violations.append(Violation(
                    description: "\(type.fullyQualifiedName) does \(shouldNotCondition.description)",
                    sourceComponent: type.fullyQualifiedName,
                    location: type.location
                ))
            }
        }

        return RuleCheckResult(
            passed: violations.isEmpty,
            ruleDescription: description,
            violations: violations
        )
    }
}

/// Builder for dependency rules
public class DependencyRuleBuilder {
    private var description: String
    private var targetCondition: ((any SwiftType), SwiftTarget) -> Bool

    /// Initialize a new dependency rule builder
    /// - Parameters:
    ///   - description: Description of the rule
    ///   - targetCondition: Function that determines if a dependency target is allowed
    private init(description: String, targetCondition: @escaping ((any SwiftType), SwiftTarget) -> Bool) {
        self.description = description
        self.targetCondition = targetCondition
    }

    /// Define that types should only depend on certain other types
    /// - Parameter condition: Condition to identify allowed dependency targets
    /// - Returns: Builder for the dependency rule
    public static func onlyDependOn(_ condition: any TypeCondition) -> DependencyRuleBuilder {
        return DependencyRuleBuilder(
            description: "only depend on types that \(condition.description)",
            targetCondition: { type, _ in condition.isSatisfiedBy(type) }
        )
    }

    /// Define that types should only depend on types in certain modules
    /// - Parameter moduleNames: Names of modules that contain allowed dependencies
    /// - Returns: Builder for the dependency rule
    public static func onlyDependOnTypes(inModules moduleNames: [String]) -> DependencyRuleBuilder {
        return DependencyRuleBuilder(
            description: "only depend on types in modules: \(moduleNames.joined(separator: ", "))",
            targetCondition: { type, _ in moduleNames.contains(type.containingModule.name) }
        )
    }

    /// Define that types should only depend on types that satisfy a custom predicate
    /// - Parameter predicate: Custom predicate to check dependencies
    /// - Returns: Builder for the dependency rule
    public static func onlyDependOnTypesWhere(_ predicate: @escaping (any SwiftType) -> Bool) -> DependencyRuleBuilder {
        return DependencyRuleBuilder(
            description: "only depend on types that satisfy custom condition",
            targetCondition: { type, _ in predicate(type) }
        )
    }

    /// Build the dependency rule
    /// - Returns: Dependency rule that can be applied to types
    internal func build() -> DependencyRule {
        return DependencyRule(description: description, targetCondition: targetCondition)
    }
}

/// Rule for checking dependencies
internal struct DependencyRule {
    let description: String
    let targetCondition: ((any SwiftType), SwiftTarget) -> Bool
}

/// Rule that checks if types satisfy dependency constraints
private class TypeDependencyRule: ArchRule {
    private let selectionConditions: [any TypeCondition]
    private let dependencyRule: DependencyRule
    public let description: String

    init(selectionConditions: [any TypeCondition], dependencyRule: DependencyRule, description: String) {
        self.selectionConditions = selectionConditions
        self.dependencyRule = dependencyRule
        self.description = description
    }

    public func check(target: SwiftTarget) -> RuleCheckResult {
        var violations: [Violation] = []

        // Collect all types from all modules
        let allTypes = target.modules.flatMap { $0.types }

        // Create a lookup dictionary for faster type resolution
        let typesByName: [String: any SwiftType] = Dictionary(
            uniqueKeysWithValues: allTypes.map { ($0.fullyQualifiedName, $0) }
        )

        // Filter types based on selection conditions
        let selectedTypes = allTypes.filter { type in
            return selectionConditions.allSatisfy { $0.isSatisfiedBy(type) }
        }

        // Check dependencies for each selected type
        for sourceType in selectedTypes {
            // In a real implementation, we would properly collect and check all dependencies
            // This is a simplified version

            // Check inheritance dependencies
            for inheritedType in sourceType.inheritedTypes {
                if let resolvedType = resolveTypeReference(inheritedType, in: typesByName) {
                    if !dependencyRule.targetCondition(resolvedType, target) {
                        violations.append(Violation(
                            description: "\(sourceType.fullyQualifiedName) depends on \(resolvedType.fullyQualifiedName) but should \(dependencyRule.description)",
                            sourceComponent: sourceType.fullyQualifiedName,
                            targetComponent: resolvedType.fullyQualifiedName,
                            location: sourceType.location
                        ))
                    }
                }
            }

            // In a real implementation, we would also check:
            // - Property types
            // - Method parameter and return types
            // - Usage dependencies (method calls, property access)
        }

        return RuleCheckResult(
            passed: violations.isEmpty,
            ruleDescription: description,
            violations: violations
        )
    }

    /// Resolve a type reference to an actual type
    /// - Parameters:
    ///   - reference: Type reference to resolve
    ///   - typesByName: Dictionary of types by fully qualified name
    /// - Returns: Resolved type, or nil if not found
    private func resolveTypeReference(_ reference: TypeReference, in typesByName: [String: any SwiftType]) -> (any SwiftType)? {
        return typesByName[reference.fullyQualifiedName]
    }
}

// MARK: - Predefined Conditions

/// Class specialization of TypesSelectionBuilder
public class ClassesSelectionBuilder: TypesSelectionBuilder {
    public override init() {
        super.init()
        _ = that(BeAClass())
    }
}

/// Struct specialization of TypesSelectionBuilder
public class StructsSelectionBuilder: TypesSelectionBuilder {
    public override init() {
        super.init()
        _ = that(BeAStruct())
    }
}

/// Protocol specialization of TypesSelectionBuilder
public class ProtocolsSelectionBuilder: TypesSelectionBuilder {
    public override init() {
        super.init()
        _ = that(BeAProtocol())
    }
}

/// Builder for selecting modules to apply rules to
public class ModulesSelectionBuilder {
    private var conditions: [any ModuleCondition] = []
    private var description: String = "modules"

    /// Filter modules that satisfy the given condition
    /// - Parameter condition: Condition to apply
    /// - Returns: Builder for further refinement
    public func that(_ condition: any ModuleCondition) -> ModulesSelectionBuilder {
        conditions.append(condition)
        description += " that \(condition.description)"
        return self
    }

    // Module-specific rules would be implemented here
}

// MARK: - Standard Conditions

/// Condition checking if a type is in a specific module
public struct ResideInModule: TypeCondition {
    public let moduleName: String
    public var description: String { "reside in module '\(moduleName)'" }

    public init(_ moduleName: String) {
        self.moduleName = moduleName
    }

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.containingModule.name == moduleName
    }
}

/// Condition checking if a type is a class
public struct BeAClass: TypeCondition {
    public var description: String { "be a class" }

    public init() {}

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.kind == .class
    }
}

/// Condition checking if a type is a struct
public struct BeAStruct: TypeCondition {
    public var description: String { "be a struct" }

    public init() {}

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.kind == .struct
    }
}

/// Condition checking if a type is a protocol
public struct BeAProtocol: TypeCondition {
    public var description: String { "be a protocol" }

    public init() {}

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.kind == .protocol
    }
}

/// Condition checking if a type is an enum
public struct BeAnEnum: TypeCondition {
    public var description: String { "be an enum" }

    public init() {}

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.kind == .enum
    }
}

/// Condition checking if a type has a name matching a pattern
public struct HaveNameMatching: TypeCondition {
    public let pattern: String
    public var description: String { "have name matching '\(pattern)'" }

    public init(_ pattern: String) {
        self.pattern = pattern
    }

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        // Simple pattern matching for now (could use regex for more advanced cases)
        return component.name.range(of: pattern) != nil
    }
}

/// Condition checking if a type has a specific attribute
public struct HaveAttribute: TypeCondition {
    public let attributeName: String
    public var description: String { "have attribute '\(attributeName)'" }

    public init(_ attributeName: String) {
        self.attributeName = attributeName
    }

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.attributes.contains { $0.name == attributeName }
    }
}

// MARK: - Convenience Functions

/// Create a condition to check if types are in a specific module
/// - Parameter moduleName: Name of the module
/// - Returns: Condition to use in rule definitions
public func resideInModule(_ moduleName: String) -> ResideInModule {
    return ResideInModule(moduleName)
}

/// Create a condition to check if types have a name matching a pattern
/// - Parameter pattern: Pattern to match against
/// - Returns: Condition to use in rule definitions
public func haveNameMatching(_ pattern: String) -> HaveNameMatching {
    return HaveNameMatching(pattern)
}

/// Create a condition to check if types have a specific attribute
/// - Parameter attributeName: Name of the attribute
/// - Returns: Condition to use in rule definitions
public func haveAttribute(_ attributeName: String) -> HaveAttribute {
    return HaveAttribute(attributeName)
}

/// Create a condition to check if a type is a class
/// - Returns: Condition to use in rule definitions
public func beAClass() -> BeAClass {
    return BeAClass()
}

/// Create a condition to check if a type is a struct
/// - Returns: Condition to use in rule definitions
public func beAStruct() -> BeAStruct {
    return BeAStruct()
}

/// Create a condition to check if a type is a protocol
/// - Returns: Condition to use in rule definitions
public func beAProtocol() -> BeAProtocol {
    return BeAProtocol()
}

/// Create a condition to check if a type is an enum
/// - Returns: Condition to use in rule definitions
public func beAnEnum() -> BeAnEnum {
    return BeAnEnum()
}

/// Condition checking if a type is in a specific package
public struct BeInPackage: TypeCondition {
    public let packagePattern: String
    public var description: String { "be in package '\(packagePattern)'" }

    public init(_ packagePattern: String) {
        self.packagePattern = packagePattern
    }

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        // Similar to ResideInPackage, could be implemented using regex matching
        let fullyQualifiedName = component.fullyQualifiedName

        // Convert packagePattern like "MyApp.Services" to regex
        let regexPattern = packagePattern.replacingOccurrences(of: ".", with: "\\.")
                                         .replacingOccurrences(of: "*", with: ".*")

        if let regex = try? NSRegularExpression(pattern: regexPattern) {
            let range = NSRange(fullyQualifiedName.startIndex..<fullyQualifiedName.endIndex,
                               in: fullyQualifiedName)
            return regex.firstMatch(in: fullyQualifiedName, range: range) != nil
        }
        return false
    }
}

/// Create a condition to check if a type is in a specific package
/// - Parameter packagePattern: Package pattern to check
/// - Returns: Condition to use in rule definitions
public func beInPackage(_ packagePattern: String) -> BeInPackage {
    return BeInPackage(packagePattern)
}

/// Condition for checking if a type depends on other types that satisfy a custom predicate
public struct DependOnTypesWhere: TypeCondition {
    public let predicate: (any SwiftType) -> Bool
    public var description: String { "depend on types that satisfy custom condition" }

    public init(_ predicate: @escaping (any SwiftType) -> Bool) {
        self.predicate = predicate
    }

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        // This is a placeholder implementation
        // In a real implementation, we would need to analyze the dependencies of the component
        return true
    }
}

/// Create a condition to check if a type depends on other types that satisfy a predicate
/// - Parameter predicate: Custom predicate to check dependencies
/// - Returns: Condition to use in rule definitions
public func dependOnTypesWhere(_ predicate: @escaping (any SwiftType) -> Bool) -> DependOnTypesWhere {
    return DependOnTypesWhere(predicate)
}

// MARK: - SwiftType Extensions

/// Extension to add convenience methods to SwiftType
extension SwiftType {
    /// Check if this type is in a package with the given pattern
    /// - Parameter packagePattern: Pattern to match against (supports wildcards)
    /// - Returns: true if the type is in the specified package
    public func isInPackage(_ packagePattern: String) -> Bool {
        // Convert packagePattern like "MyApp.Features.*" to regex
        let regexPattern = packagePattern.replacingOccurrences(of: ".", with: "\\.")
                                         .replacingOccurrences(of: "*", with: ".*")

        if let regex = try? NSRegularExpression(pattern: regexPattern) {
            let range = NSRange(fullyQualifiedName.startIndex..<fullyQualifiedName.endIndex,
                               in: fullyQualifiedName)
            return regex.firstMatch(in: fullyQualifiedName, range: range) != nil
        }
        return false
    }

    /// Check if this type is from the Swift standard library
    /// - Returns: true if the type is from the standard library
    public func isInStandardLibrary() -> Bool {
        // Check if the module name is one of the standard library modules
        let standardLibraryModules = ["Swift", "Foundation", "Combine", "SwiftUI", "UIKit", "CoreData"]
        return standardLibraryModules.contains(containingModule.name)
    }

    /// Check if this type has a specific attribute
    /// - Parameter attributeName: Name of the attribute to check for
    /// - Returns: true if the type has the specified attribute
    public func hasAttribute(_ attributeName: String) -> Bool {
        return attributes.contains { $0.name == attributeName }
    }
}

/// Condition for access modifiers
struct HaveModifier: TypeCondition {
    let accessLevel: AccessLevel
    var description: String { "have \(accessLevel.rawValue) access level" }

    init(_ accessLevel: AccessLevel) {
        self.accessLevel = accessLevel
    }

    func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.accessLevel == accessLevel
    }
}

/// Helper function for access modifier checks
func haveModifier(_ accessLevel: AccessLevel) -> HaveModifier {
    return HaveModifier(accessLevel)
}


// MARK: - Additional Conditions

/// Condition checking if a type conforms to a specific protocol
public struct ConformTo: TypeCondition {
    public let protocolName: String
    public var description: String { "conform to '\(protocolName)'" }

    public init(_ protocolName: String) {
        self.protocolName = protocolName
    }

    public func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        return component.conformances.contains { $0.name == protocolName }
    }
}

/// Create a condition to check if a type conforms to a protocol
/// - Parameter protocolName: Name of the protocol
/// - Returns: Condition to use in rule definitions
public func conformTo(_ protocolName: String) -> ConformTo {
    return ConformTo(protocolName)
}

struct ResideInPackage: TypeCondition {
    let packagePattern: String
    var description: String { "reside in package matching '\(packagePattern)'" }

    init(_ packagePattern: String) {
        self.packagePattern = packagePattern
    }

    func isSatisfiedBy(_ component: any SwiftType) -> Bool {
        // Convert packagePattern like "MyApp.Features.*" to regex
        let regexPattern = packagePattern.replacingOccurrences(of: ".", with: "\\.")
                                         .replacingOccurrences(of: "*", with: ".*")

        if let regex = try? NSRegularExpression(pattern: regexPattern) {
            let range = NSRange(component.fullyQualifiedName.startIndex..<component.fullyQualifiedName.endIndex,
                               in: component.fullyQualifiedName)
            return regex.firstMatch(in: component.fullyQualifiedName, range: range) != nil
        }
        return false
    }
}

/// Helper function for package pattern matching
func resideInPackage(_ packagePattern: String) -> ResideInPackage {
    return ResideInPackage(packagePattern)
}
