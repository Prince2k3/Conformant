import Foundation

/// Base protocol for architecture rules
public protocol ArchitectureRule {
    var ruleDescription: String { get }
    var violations: [ArchitectureViolation] { get set }

    func check(context: inout ArchitectureRuleContext) -> Bool
}
