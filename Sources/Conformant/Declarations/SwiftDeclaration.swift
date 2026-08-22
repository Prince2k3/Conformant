//
//  SwiftDeclaration.swift
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

/// Base protocol for all Swift declarations
public protocol SwiftDeclaration {
    /// The declaration's name, qualified by its enclosing types when nested (`Outer.Inner`).
    var name: String { get }
    var modifiers: [SwiftModifier] { get }
    var annotations: [SwiftAnnotation] { get }
    var dependencies: [SwiftDependency] { get }
    var filePath: String { get }
    var location: SourceLocation { get }

    /// The qualified name of the enclosing type, or `nil` for a top-level declaration.
    ///
    /// Nested declarations were invisible before they carried a parent: they either went
    /// uncollected or their members were folded into the enclosing type. A rule can now
    /// tell `Outer.Inner` from a top-level `Inner`.
    var parentName: String? { get }

    func hasAnnotation(named: String) -> Bool
    func hasModifier(_ modifier: SwiftModifier) -> Bool
    func resideInPackage(_ packagePattern: String) -> Bool
}

/// Default implementation for SwiftDeclaration methods
extension SwiftDeclaration {
    /// Declarations that cannot nest report no parent.
    public var parentName: String? { nil }

    /// `true` when the declaration is written inside another type.
    public var isNested: Bool { parentName != nil }

    /// The declaration's own name without the enclosing-type qualification:
    /// `Inner` for a declaration named `Outer.Inner`.
    public var simpleName: String {
        guard let parentName, name.hasPrefix(parentName + ".") else { return name }
        return String(name.dropFirst(parentName.count + 1))
    }

    public func hasAnnotation(named name: String) -> Bool {
        annotations.contains { $0.name == name }
    }

    public func hasModifier(_ modifier: SwiftModifier) -> Bool {
        modifiers.contains(modifier)
    }

    public func resideInPackage(_ packagePattern: String) -> Bool {
        let regexPattern = packagePattern.replacingOccurrences(of: "..", with: ".*")

        do {
            let regex = try Regex(regexPattern)
            return filePath.contains(regex)
        } catch {
            print("Invalid regex pattern: \(regexPattern) - \(error)")
            return false
        }
    }
}
