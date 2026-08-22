//
//  DependencyKind.swift
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

/// Describes the nature of a dependency relationship.
public enum DependencyKind: Hashable {
    case inheritance
    case conformance
    /// A type written down: a parameter, a return type, a property annotation, an alias.
    case typeUsage
    /// A type constructed in a body, as in `UserRepository()`.
    case instantiation
    /// A static or class member reached in a body, as in `DatabaseClient.shared`.
    case staticAccess
    /// A bound on a generic parameter, the `Codable` in `func send<T: Codable>(_ value: T)`.
    case genericConstraint
    case `extension`
    case `import`
}

extension DependencyKind {
    /// Whether a layer rule should consider this dependency when deciding whether one
    /// layer reaches into another.
    ///
    /// `.extension` is the only exclusion: the extended type is the declaration's own
    /// subject rather than something it reaches out to. `.import` counts: a module named
    /// by a layer is reached the moment a file in another layer imports it, and the import
    /// declaration is the declaration that reached for it.
    ///
    /// The switch is exhaustive on purpose. A rule that quietly skipped a real dependency
    /// would pass while the coupling it was written to catch went unreported, so a new
    /// kind has to be classified here before it compiles.
    public var isSubjectToLayerRules: Bool {
        switch self {
        case .extension:
            return false
        case .import, .inheritance, .conformance, .typeUsage,
             .instantiation, .staticAccess, .genericConstraint:
            return true
        }
    }
}
