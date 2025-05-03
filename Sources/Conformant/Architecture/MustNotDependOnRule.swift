//
//  MustNotDependOnRule.swift
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
