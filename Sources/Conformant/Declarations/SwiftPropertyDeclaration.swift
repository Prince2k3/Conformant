//
//  SwiftPropertyDeclaration.swift
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

/// Represents a Swift property declaration
public class SwiftPropertyDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let type: String
    public let isComputed: Bool
    public let initialValue: String?

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        type: String,
        isComputed: Bool,
        initialValue: String?
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.type = type
        self.isComputed = isComputed
        self.initialValue = initialValue
    }
}
