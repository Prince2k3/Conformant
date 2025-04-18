import Foundation

/// Rule that enforces a layer does not depend on specified layers
public class MustNotDependOnRule: ArchitectureRule {
    let source: Layer
    let forbiddenLayers: [Layer]
    public var violations: [ArchitectureViolation] = []

    public var ruleDescription: String {
        let forbiddenNames = forbiddenLayers.map { $0.name }.joined(separator: ", ")
        return "Layer '\(source.name)' must not depend on: \(forbiddenNames)"
    }

    init(source: Layer, forbiddenLayers: [Layer]) {
        self.source = source
        self.forbiddenLayers = forbiddenLayers
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
                    if forbiddenLayers.contains(where: { $0.name == dependencyLayer.name }) {
                        violations.append(ArchitectureViolation(
                            sourceDeclaration: declaration,
                            dependency: dependency,
                            ruleDescription: ruleDescription,
                            detail: "Depends on forbidden layer '\(dependencyLayer.name)'"
                        ))
                    }
                }
            }
        }

        return violations.isEmpty
    }
}
