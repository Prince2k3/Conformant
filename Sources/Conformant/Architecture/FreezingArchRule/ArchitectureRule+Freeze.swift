import Foundation

extension ArchitectureRule {
    /// Creates a freezing version of this rule
    /// - Parameters:
    ///   - violationStore: The store for violations
    ///   - lineMatcher: The matcher for comparing violations
    /// - Returns: A freezing architecture rule that wraps this rule
    public func freeze(using violationStore: ViolationStore,
                       matching lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) -> FreezingArchRule {
        return FreezingArchRule(rule: self, violationStore: violationStore, lineMatcher: lineMatcher)
    }

    /// Creates a freezing version of this rule using a file-based violation store
    /// - Parameter filePath: The path to the JSON file where violations will be stored
    /// - Returns: A freezing architecture rule that wraps this rule
    public func freeze(toFile filePath: String) -> FreezingArchRule {
        let store = FileViolationStore(filePath: filePath)
        return FreezingArchRule(rule: self, violationStore: store)
    }
}
