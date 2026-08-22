//
//  SwiftActorDeclaration.swift
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

/// Represents a Swift actor declaration.
///
/// Actors are reference types like classes but cannot inherit from another actor, so
/// there is no superclass — every inherited type in the clause is a conformance.
public class SwiftActorDeclaration: SwiftDeclaration {
    public let name: String
    public let modifiers: [SwiftModifier]
    public let annotations: [SwiftAnnotation]
    public let dependencies: [SwiftDependency]
    public let filePath: String
    public let location: SourceLocation
    public let parentName: String?
    public let protocols: [String]
    public let properties: [SwiftPropertyDeclaration]
    public let methods: [SwiftFunctionDeclaration]
    public let subscripts: [SwiftSubscriptDeclaration]
    public let deinitializers: [SwiftDeinitializerDeclaration]

    init(
        name: String,
        modifiers: [SwiftModifier],
        annotations: [SwiftAnnotation],
        dependencies: [SwiftDependency],
        filePath: String,
        location: SourceLocation,
        protocols: [String],
        properties: [SwiftPropertyDeclaration],
        methods: [SwiftFunctionDeclaration],
        subscripts: [SwiftSubscriptDeclaration] = [],
        deinitializers: [SwiftDeinitializerDeclaration] = [],
        parentName: String? = nil
    ) {
        self.name = name
        self.modifiers = modifiers
        self.annotations = annotations
        self.dependencies = dependencies
        self.filePath = filePath
        self.location = location
        self.protocols = protocols
        self.properties = properties
        self.methods = methods
        self.subscripts = subscripts
        self.deinitializers = deinitializers
        self.parentName = parentName
    }

    /// `true` when the actor is annotated `@globalActor`.
    public var isGlobalActor: Bool {
        hasAnnotation(named: "globalActor")
    }

    /// `true` when the actor is declared `distributed actor`.
    public var isDistributed: Bool {
        hasModifier(.distributed)
    }

    public func hasProperty(named name: String) -> Bool {
        properties.contains { $0.name == name }
    }

    public func hasMethod(named name: String) -> Bool {
        methods.contains { $0.name == name }
    }

    public func implements(protocol protocolName: String) -> Bool {
        protocols.contains(protocolName)
    }
}
