import Foundation

/// Rule that enforces a layer doesn't depend on any other layer
public class DependsOnNothingRule: ArchitectureRule {
    let source: Layer
    public var violations: [ArchitectureViolation] = []

    public var ruleDescription: String {
        return "Layer '\(source.name)' should not depend on any other layer"
    }

    init(source: Layer) {
        self.source = source
    }

    public func check(context: inout ArchitectureRuleContext) -> Bool {
        violations = []

        let sourceDeclarations = context.declarationsInLayer(source)

        for declaration in sourceDeclarations {
            for dependency in declaration.dependencies {
                if dependency.kind != .typeUsage && dependency.kind != .inheritance && dependency.kind != .conformance {
                    continue
                }

                if !source.resideIn(declaration) {
                    violations.append(ArchitectureViolation(
                        sourceDeclaration: declaration,
                        dependency: dependency,
                        ruleDescription: ruleDescription,
                        detail: "Depends on external type '\(dependency.name)'"
                    ))
                }
            }
        }

        return violations.isEmpty
    }
}
