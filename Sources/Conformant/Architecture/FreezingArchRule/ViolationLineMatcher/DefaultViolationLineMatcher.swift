import Foundation

/// Default implementation of ViolationLineMatcher that ignores line numbers within the same file/class
public struct DefaultViolationLineMatcher: ViolationLineMatcher {
    public init() {}
    
    public func matches(stored: StoredViolation, actual: ArchitectureViolation) -> Bool {
        // Match if same file, same declaration name, and same rule violation
        return stored.filePath == actual.sourceDeclaration.filePath &&
        stored.declarationName == actual.sourceDeclaration.name &&
        stored.ruleDescription == actual.ruleDescription &&
        stored.detail == actual.detail
    }
}
