//
//  SwiftFile.swift
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

/// Represents a Swift source file
public struct SwiftFile {
    let path: String
    let imports: [SwiftImportDeclaration]
    let classes: [SwiftClassDeclaration]
    let structs: [SwiftStructDeclaration]
    let protocols: [SwiftProtocolDeclaration]
    let extensions: [SwiftExtensionDeclaration]
    let functions: [SwiftFunctionDeclaration]
    let properties: [SwiftPropertyDeclaration]
    let enums: [SwiftEnumDeclaration]

    var internalDependencies: [SwiftDependency] {
        var deps: [SwiftDependency] = []
        deps.append(contentsOf: classes.flatMap { $0.dependencies })
        deps.append(contentsOf: structs.flatMap { $0.dependencies })
        deps.append(contentsOf: protocols.flatMap { $0.dependencies })
        deps.append(contentsOf: extensions.flatMap { $0.dependencies })
        deps.append(contentsOf: functions.flatMap { $0.dependencies })
        deps.append(contentsOf: properties.flatMap { $0.dependencies })
        deps.append(contentsOf: enums.flatMap { $0.dependencies })
        return deps
    }

    /// Dependencies originating from import statements in this file.
    var importDependencies: [SwiftDependency] {
        return imports.map {
            SwiftDependency(name: $0.name, kind: .import, location: $0.location)
            
            // SwiftDependency(name: $0.fullPath, kind: .import, location: $0.location)
        }
    }
}
