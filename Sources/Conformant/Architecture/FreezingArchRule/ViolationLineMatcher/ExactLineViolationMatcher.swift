import Foundation

/// Line matcher that requires exact line matches
public struct ExactLineViolationMatcher: ViolationLineMatcher {
    public init() {}
    
    public func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool {
        return stored.filePath == actual.sourceDeclaration.filePath &&
        stored.line == actual.sourceDeclaration.location.line &&
        stored.ruleDescription == actual.ruleDescription
    }
}
