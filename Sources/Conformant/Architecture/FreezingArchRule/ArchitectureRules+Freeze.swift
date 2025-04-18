import Foundation

extension ArchitectureRules {
    /// Adds a freezing version of a rule
    /// - Parameters:
    ///   - rule: The rule to wrap
    ///   - violationStore: The store for violations
    ///   - lineMatcher: The matcher for comparing violations
    public func addFreezing(_ rule: ArchitectureRule, 
                            using violationStore: ViolationStore, 
                            matching lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) {
        add(rule.freeze(using: violationStore, matching: lineMatcher))
    }
    
    /// Adds a freezing version of a rule using a file-based violation store
    /// - Parameters:
    ///   - rule: The rule to wrap
    ///   - filePath: The path to the JSON file where violations will be stored
    public func addFreezing(_ rule: ArchitectureRule, toFile filePath: String) {
        add(rule.freeze(toFile: filePath))
    }
    
    /// Freezes all rules in a specified directory
    /// - Parameter directory: The directory where violation files will be stored
    public func freezeAllRules(inDirectory directory: String) {
        // Ensure the directory exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory) {
            try? fileManager.createDirectory(at: URL(fileURLWithPath: directory), 
                                             withIntermediateDirectories: true)
        }
        
        // Replace rules with frozen versions
        let originalRules = rules
        rules = []
        
        for (index, rule) in originalRules.enumerated() {
            // Generate a filename based on the rule description
            let sanitizedDesc = rule.ruleDescription
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
                .replacingOccurrences(of: ":", with: "")
            
            let fileName = "rule_\(index)_\(sanitizedDesc).json"
            let filePath = (directory as NSString).appendingPathComponent(fileName)
            
            add(rule.freeze(toFile: filePath))
        }
    }
}
