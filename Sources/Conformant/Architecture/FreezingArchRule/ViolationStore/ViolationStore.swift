import Foundation

/// Protocol for storing and retrieving architecture rule violations
public protocol ViolationStore {
    /// Loads the stored violations from the store
    func loadViolations() -> [StoredViolation]
    
    /// Saves violations to the store
    func saveViolations(_ violations: [StoredViolation])
}
