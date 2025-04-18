import Foundation

/// Wraps an architecture rule with freezing functionality
public class FreezingArchRule: ArchitectureRule {
    private var wrappedRule: ArchitectureRule
    private let violationStore: ViolationStore
    private let lineMatcher: ViolationLineMatcher
    
    public var ruleDescription: String {
        return "Freezing: " + wrappedRule.ruleDescription
    }
    
    public var violations: [ArchitectureViolation] {
        get { return wrappedRule.violations }
        set { wrappedRule.violations = newValue }
    }
    
    /// Creates a new freezing architecture rule
    /// - Parameters:
    ///   - rule: The rule to wrap
    ///   - violationStore: The store for violations
    ///   - lineMatcher: The matcher for comparing violations
    public init(rule: ArchitectureRule, 
                violationStore: ViolationStore, 
                lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) {
        self.wrappedRule = rule
        self.violationStore = violationStore
        self.lineMatcher = lineMatcher
    }
    
    public func check(context: inout ArchitectureRuleContext) -> Bool {
        // Check the wrapped rule first
        let ruleResult = wrappedRule.check(context: &context)
        
        // If the rule passes and there are no violations, there's nothing more to do
        if ruleResult && wrappedRule.violations.isEmpty {
            // The rule passed cleanly - clear any stored violations since all issues are fixed
            violationStore.saveViolations([])
            return true
        }
        
        // Load stored violations
        let storedViolations = violationStore.loadViolations()
        
        // Filter the current violations to only include new ones
        var newViolations: [ArchitectureViolation] = []
        var updatedStoredViolations: [StoredViolation] = []
        
        // Keep track of which stored violations are still relevant
        var matchedStoredViolationIndices = Set<Int>()
        
        // Find new violations (those not in stored violations)
        for currentViolation in wrappedRule.violations {
            // Check if this violation is already stored
            var isNewViolation = true
            
            for (index, storedViolation) in storedViolations.enumerated() {
                if lineMatcher.matches(stored: storedViolation, actual: currentViolation) {
                    isNewViolation = false
                    matchedStoredViolationIndices.insert(index)
                    break
                }
            }
            
            if isNewViolation {
                newViolations.append(currentViolation)
            }
        }
        
        // Update stored violations to keep only those that still exist
        for (index, storedViolation) in storedViolations.enumerated() {
            if matchedStoredViolationIndices.contains(index) {
                updatedStoredViolations.append(storedViolation)
            }
        }
        
        // Add new violations to the stored list
        for newViolation in newViolations {
            updatedStoredViolations.append(StoredViolation(from: newViolation))
        }
        
        // Save the updated violations list
        let uniqueViolations = Array(Set(updatedStoredViolations))
        violationStore.saveViolations(uniqueViolations)

        // Replace the wrapped rule's violations with only the new ones
        wrappedRule.violations = newViolations
        
        // Return success if there are no new violations
        return newViolations.isEmpty
    }
}
