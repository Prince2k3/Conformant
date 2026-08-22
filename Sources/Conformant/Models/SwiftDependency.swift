//
//  SwiftDependency.swift
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

/// Represents a dependency from one declaration/file to another type or module.
public struct SwiftDependency: Hashable {
    /// The name of the type or module being depended upon (e.g., "UIViewController", "Codable", "Foundation").
    public let name: String
    /// The kind of dependency relationship.
    public let kind: DependencyKind
    /// The location in the source file where this dependency occurs.
    public let location: SourceLocation
    /// The written type this dependency came from, when there was one: its generic
    /// arguments, the form it appeared in, and how it was qualified. `nil` for
    /// dependencies that are not written types, such as `import` and inferred names.
    public let reference: TypeReference?

    init(name: String, kind: DependencyKind, location: SourceLocation, reference: TypeReference? = nil) {
        self.name = name
        self.kind = kind
        self.location = location
        self.reference = reference
    }

    /// Whether `name` names this dependency.
    ///
    /// A qualified dependency answers to any suffix of its name that starts at a
    /// component boundary, so `Foundation.URL` matches both `Foundation.URL` and `URL`.
    /// Equality is still exact; this is for rules and filters, which are written against
    /// the type name an author has in mind rather than the one the source happened to use.
    public func matches(_ name: String) -> Bool {
        if self.name == name { return true }
        return self.name.hasSuffix(".\(name)")
    }

    // Implement Hashable for Set operations later if needed
    public static func == (lhs: SwiftDependency, rhs: SwiftDependency) -> Bool {
        return lhs.name == rhs.name && lhs.kind == rhs.kind &&
        lhs.location.file == rhs.location.file && // Basic location equality
        lhs.location.line == rhs.location.line &&
        lhs.location.column == rhs.location.column
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(kind)
        hasher.combine(location.file)
        hasher.combine(location.line)
        hasher.combine(location.column)
    }
}
