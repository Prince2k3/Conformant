//
//  SwiftFunctionDeclaration.swift
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

/// Represents a Swift function declaration
public class SwiftFunctionDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let parameters: [SwiftParameterDeclaration]
    public let returnType: String?
    public let body: String?  // Function body as a string
    public let isAsync: Bool
    public let isThrowing: Bool
    public let effectSpecifiers: FunctionEffectSpecifiers

    /// Represents the effect specifiers of a function (async, throws, etc.)
    public struct FunctionEffectSpecifiers {
        public let isAsync: Bool
        public let isThrowing: Bool
        public let isRethrows: Bool

        public init(isAsync: Bool = false, isThrowing: Bool = false, isRethrows: Bool = false) {
            self.isAsync = isAsync
            self.isThrowing = isThrowing
            self.isRethrows = isRethrows
        }
    }

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        parameters: [SwiftParameterDeclaration],
        returnType: String?,
        body: String?,
        effectSpecifiers: FunctionEffectSpecifiers = FunctionEffectSpecifiers()
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.parameters = parameters
        self.returnType = returnType
        self.body = body
        self.isAsync = effectSpecifiers.isAsync
        self.isThrowing = effectSpecifiers.isThrowing || effectSpecifiers.isRethrows
        self.effectSpecifiers = effectSpecifiers
    }

    public func hasParameter(named name: String) -> Bool {
        return parameters.contains { $0.name == name }
    }

    public func hasReturnType() -> Bool {
        return returnType != nil && returnType != "Void" && returnType != "()"
    }

    /// Returns true if the function uses 'rethrows' instead of 'throws'
    public func isRethrowing() -> Bool {
        return effectSpecifiers.isRethrows
    }
}
