import Foundation

/// Extension to add architecture verification to SwiftScope
extension Conformant {
    public func assertArchitecture(_ defineRules: (ArchitectureRules) -> Void) -> Bool {
        let ruleSet = ArchitectureRules()
        defineRules(ruleSet)

        var context = ArchitectureRuleContext(
            scope: self,
            declarations: self.declarations(),
            layers: Array(ruleSet.layers.values)
        )

        var allPassed = true
        for rule in ruleSet.rules {
            if !rule.check(context: &context) {
                allPassed = false

                print("Rule Failed: \(rule.ruleDescription)")
                for violation in rule.violations {
                    print("  \(violation.detail) in \(violation.sourceDeclaration.name) at \(violation.sourceDeclaration.filePath):\(violation.sourceDeclaration.location.line)")
                }
            }
        }
        return allPassed
    }
} 
