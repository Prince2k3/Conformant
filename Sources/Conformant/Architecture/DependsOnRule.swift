//
//  DependsOnRule.swift
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
