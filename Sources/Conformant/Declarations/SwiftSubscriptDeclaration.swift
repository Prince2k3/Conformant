//
//  SwiftSubscriptDeclaration.swift
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

/// Represents a Swift subscript declaration.
///
/// Subscripts have no identifier of their own, so they are named `subscript`. Use
/// ``parameters`` and ``returnType`` to tell overloads apart.
public class SwiftSubscriptDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let parentName: String?
    public let parameters: [SwiftParameterDeclaration]
    public let returnType: String

    /// Accessor keywords written in the subscript's body, e.g. `["get", "set"]`.
    /// Empty for a protocol requirement written without a body, or for a
    /// getter-only shorthand (`subscript(i: Int) -> T { expression }`).
    public let accessors: [String]

    init(
        name: String = "subscript",
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        parameters: [SwiftParameterDeclaration],
        returnType: String,
        accessors: [String] = [],
        parentName: String? = nil
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.parameters = parameters
        self.returnType = returnType
        self.accessors = accessors
        self.parentName = parentName
    }

    /// `true` when the subscript declares a setter.
    public var isSettable: Bool { accessors.contains("set") }
}
