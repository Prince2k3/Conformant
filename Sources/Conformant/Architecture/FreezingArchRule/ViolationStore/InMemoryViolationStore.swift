import Foundation

/// Implementation of ViolationStore that stores violations in memory
public class InMemoryViolationStore: ViolationStore {
    private var violations: [StoredViolation] = []
    
    public init() {}
    
    public func loadViolations() -> [StoredViolation] {
        return violations
    }
    
    public func saveViolations(_ violations: [StoredViolation]) {
        self.violations = violations
    }
}
