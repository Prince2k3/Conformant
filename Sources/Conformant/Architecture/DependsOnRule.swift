import Foundation

/// Rule that enforces one layer depends on another
public class DependsOnRule: ArchitectureRule {
    let source: Layer
    let target: Layer
    public var violations: [ArchitectureViolation] = []

    public var ruleDescription: String {
        return "Layer '\(source.name)' should depend on layer '\(target.name)'"
    }

    init(source: Layer, target: Layer) {
        self.source = source
        self.target = target
    }

    public func check(context: inout ArchitectureRuleContext) -> Bool {
        violations = []

        let sourceDeclarations = context.declarationsInLayer(source)

        for declaration in sourceDeclarations {
            for dependency in declaration.dependencies {
                if dependency.kind != .typeUsage && dependency.kind != .inheritance && dependency.kind != .conformance {
                    continue
                }

                if let dependencyLayer = context.layerContaining(dependency: dependency) {
                    if dependencyLayer.name != target.name {
                        violations.append(ArchitectureViolation(
                            sourceDeclaration: declaration,
                            dependency: dependency,
                            ruleDescription: ruleDescription,
                            detail: "Uses '\(dependency.name)' from layer '\(dependencyLayer.name)' instead of '\(target.name)'"
                        ))
                    }
                }
            }
        }

        return violations.isEmpty
    }
}
