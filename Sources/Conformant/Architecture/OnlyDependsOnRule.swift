import Foundation

/// Rule that enforces a layer can only depend on specified layers
public class OnlyDependsOnRule: ArchitectureRule {
    let source: Layer
    let targetLayers: [Layer]
    public var violations: [ArchitectureViolation] = []

    public var ruleDescription: String {
        let targetNames = targetLayers.map { $0.name }.joined(separator: ", ")
        return "Layer '\(source.name)' should only depend on: \(targetNames)"
    }

    init(source: Layer, targetLayers: [Layer]) {
        self.source = source
        self.targetLayers = targetLayers
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
                    if dependencyLayer.name != source.name && !targetLayers.contains(where: { $0.name == dependencyLayer.name }) {
                        violations.append(ArchitectureViolation(
                            sourceDeclaration: declaration,
                            dependency: dependency,
                            ruleDescription: ruleDescription,
                            detail: "Depends on disallowed layer '\(dependencyLayer.name)'"
                        ))
                    }
                }
            }
        }

        return violations.isEmpty
    }
}
