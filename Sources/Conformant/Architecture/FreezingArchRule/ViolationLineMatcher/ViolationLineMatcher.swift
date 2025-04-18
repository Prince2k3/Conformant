import Foundation

/// Protocol for matching stored violations with new violations
public protocol ViolationLineMatcher {
    /// Determines if a stored violation matches a new violation
    func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool
}
