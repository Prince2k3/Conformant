import Foundation

/// Represents a violation of an architecture rule
public struct ArchitectureViolation {
    let sourceDeclaration: any SwiftDeclaration
    let dependency: SwiftDependency
    let ruleDescription: String
    let detail: String
}
