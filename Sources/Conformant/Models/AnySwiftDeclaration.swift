//
//  AnySwiftDeclaration.swift
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

public struct AnySwiftDeclaration: SwiftDeclaration {
    private let _declaration: any SwiftDeclaration

    public init<ConcreteDecl: SwiftDeclaration>(_ declaration: ConcreteDecl) {
        self._declaration = declaration
    }

    public var name: String {
        _declaration.name
    }

    public var dependencies: [SwiftDependency] {
        _declaration.dependencies
    }

    public var modifiers: [SwiftModifier] {
        _declaration.modifiers
    }

    public var annotations: [SwiftAnnotation] {
        _declaration.annotations
    }

    public var filePath: String {
        _declaration.filePath
    }

    public var location: SourceLocation {
        _declaration.location
    }

    public func hasAnnotation(named name: String) -> Bool {
        _declaration.hasAnnotation(named: name)
    }

    public func hasModifier(_ modifier: SwiftModifier) -> Bool {
        _declaration.hasModifier(modifier)
    }

    public func resideInPackage(_ packagePattern: String) -> Bool {
        _declaration.resideInPackage(packagePattern)
    }
}
