import Foundation

/// Represents a stored violation for freezing architecture rules
public struct StoredViolation: Codable, Hashable {
    /// The source file where the violation occurred
    public let filePath: String
    
    /// The line number where the violation occurred
    public let line: Int
    
    /// The rule that was violated
    public let ruleDescription: String
    
    /// Details about the violation
    public let detail: String
    
    /// The declaration name that caused the violation
    public let declarationName: String
    
    /// Creates a new stored violation from an architecture violation
    public init(from violation: ArchitectureViolation) {
        self.filePath = violation.sourceDeclaration.filePath
        self.line = violation.sourceDeclaration.location.line
        self.ruleDescription = violation.ruleDescription
        self.detail = violation.detail
        self.declarationName = violation.sourceDeclaration.name
    }
    
    /// Creates a new stored violation explicitly
    public init(filePath: String, line: Int, ruleDescription: String, detail: String, declarationName: String) {
        self.filePath = filePath
        self.line = line
        self.ruleDescription = ruleDescription
        self.detail = detail
        self.declarationName = declarationName
    }
}
