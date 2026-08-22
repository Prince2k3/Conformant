//
//  ArchitectureRules.swift
//  Conformant
//
//  Copyright © 2025 Prince Ugwuh. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// Container for architecture rules
public class ArchitectureRules {
    var rules: [ArchitectureRule] = []

    /// Layers in the order they were defined.
    ///
    /// Order matters: a declaration can satisfy more than one layer predicate,
    /// and the first matching layer wins. Keeping definition order makes rule
    /// evaluation reproducible across runs.
    private(set) var layers: [Layer] = []

    private var layersByName: [String: Int] = [:]

    /// Add a rule to the architecture rules
    public func add(_ rule: ArchitectureRule) {
        rules.append(rule)
    }

    /// Define a layer in the architecture
    ///
    /// Redefining a layer with an existing name replaces it in place, keeping
    /// its original position in the evaluation order.
    public func defineLayer(_ layer: Layer) {
        if let existingIndex = layersByName[layer.name] {
            layers[existingIndex] = layer
        } else {
            layersByName[layer.name] = layers.count
            layers.append(layer)
        }
    }

    /// Get a layer by name
    public func layer(_ name: String) -> Layer? {
        guard let index = layersByName[name] else { return nil }
        return layers[index]
    }
}
