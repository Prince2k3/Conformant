import Foundation

/// Container for architecture rules
public class ArchitectureRules {
    var rules: [ArchitectureRule] = []
    var layers: [String: Layer] = [:]

    /// Add a rule to the architecture rules
    public func add(_ rule: ArchitectureRule) {
        rules.append(rule)
    }

    /// Define a layer in the architecture
    public func defineLayer(_ layer: Layer) {
        layers[layer.name] = layer
    }

    /// Get a layer by name
    public func layer(_ name: String) -> Layer? {
        return layers[name]
    }
}
