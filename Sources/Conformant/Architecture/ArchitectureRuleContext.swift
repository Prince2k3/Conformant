//
//  ArchitectureRuleContext.swift
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

/// Context provided to architecture rules for checking
public struct ArchitectureRuleContext {
    let scope: Conformant
    let declarations: [any SwiftDeclaration]
    let layers: [Layer]

    private var typeToLayerCache: [String: Layer?] = [:]

    init(scope: Conformant, declarations: [any SwiftDeclaration], layers: [Layer]) {
        self.scope = scope
        self.declarations = declarations
        self.layers = layers
    }

    /// Find all declarations in a specific layer
    func declarationsInLayer(_ layer: Layer) -> [any SwiftDeclaration] {
        return declarations.filter { layer.resideIn($0) }
    }

    /// Determine which layer a declaration belongs to
    func layerContaining(declaration: any SwiftDeclaration) -> Layer? {
        for layer in layers {
            if layer.resideIn(declaration) {
                return layer
            }
        }
        return nil
    }

    /// Determine which layer a dependency belongs to
    mutating func layerContaining(dependency: SwiftDependency) -> Layer? {
        if let cachedLayer = typeToLayerCache[dependency.name] {
            return cachedLayer
        }

        if dependency.kind == .import {
            for layer in layers {
                if layer.containsDependency(dependency) {
                    typeToLayerCache[dependency.name] = layer
                    return layer
                }
            }

            typeToLayerCache[dependency.name] = nil

            return nil
        }

        let matchingDeclarations = declarations.filter {
            $0.name == dependency.name
        }

        for declaration in matchingDeclarations {
            if let layer = layerContaining(declaration: declaration) {
                typeToLayerCache[dependency.name] = layer
                return layer
            }
        }

        typeToLayerCache[dependency.name] = nil
        return nil
    }

    /// Check if a dependency is from one layer to another
    mutating func isDependency(from sourceLayer: Layer, to targetLayer: Layer, dependency: SwiftDependency) -> Bool {
        if dependency.kind == .import && targetLayer.containsDependency(dependency) {
            return true
        }

        if let dependencyLayer = layerContaining(dependency: dependency) {
            return dependencyLayer.name == targetLayer.name
        }

        return false
    }
}
