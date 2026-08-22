//
//  SwiftModifier.swift
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

/// Represents a Swift declaration modifier like `public`, `static`, or `nonisolated`.
///
/// The list is open: a modifier the parser does not recognize is preserved as
/// ``unknown(_:)`` rather than dropped. Silently discarding a keyword would make a
/// declaration look less restricted than it is, so an unfamiliar modifier stays visible
/// to rules and to `withModifier(_:)`.
public enum SwiftModifier: Hashable, Sendable {
    // Access control
    case `open`
    case `public`
    case package
    case `internal`
    case `fileprivate`
    case `private`

    // Placement and storage
    case `static`
    case `class`
    case `final`
    case lazy
    case weak
    case unowned
    case indirect

    // Members
    case required
    case convenience
    case mutating
    case nonmutating
    case `override`
    case optional
    case dynamic

    // Concurrency and ownership
    case nonisolated
    case isolated
    case distributed
    case borrowing
    case consuming

    // Operator fixity
    case prefix
    case infix
    case postfix

    /// A modifier keyword the parser does not model. Carries the source spelling so a
    /// future Swift keyword is visible in rules and diagnostics instead of vanishing.
    case unknown(String)

    /// Every modifier the parser recognizes by name, in declaration order.
    static let known: [SwiftModifier] = [
        .open, .public, .package, .internal, .fileprivate, .private,
        .static, .class, .final, .lazy, .weak, .unowned, .indirect,
        .required, .convenience, .mutating, .nonmutating, .override, .optional, .dynamic,
        .nonisolated, .isolated, .distributed, .borrowing, .consuming,
        .prefix, .infix, .postfix
    ]

    private static let byKeyword: [String: SwiftModifier] = Dictionary(
        uniqueKeysWithValues: known.map { ($0.rawValue, $0) }
    )

    /// `true` when the modifier is one the parser models by name.
    public var isKnown: Bool {
        if case .unknown = self { return false }
        return true
    }
}

extension SwiftModifier: RawRepresentable {
    /// Non-failable: an unrecognized keyword becomes ``unknown(_:)``.
    ///
    /// It still satisfies `RawRepresentable`'s failable requirement, so `SwiftModifier(rawValue:)`
    /// keeps working at existing call sites — it just never returns `nil`.
    public init(rawValue: String) {
        self = SwiftModifier.byKeyword[rawValue] ?? .unknown(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .open: return "open"
        case .public: return "public"
        case .package: return "package"
        case .internal: return "internal"
        case .fileprivate: return "fileprivate"
        case .private: return "private"
        case .static: return "static"
        case .class: return "class"
        case .final: return "final"
        case .lazy: return "lazy"
        case .weak: return "weak"
        case .unowned: return "unowned"
        case .indirect: return "indirect"
        case .required: return "required"
        case .convenience: return "convenience"
        case .mutating: return "mutating"
        case .nonmutating: return "nonmutating"
        case .override: return "override"
        case .optional: return "optional"
        case .dynamic: return "dynamic"
        case .nonisolated: return "nonisolated"
        case .isolated: return "isolated"
        case .distributed: return "distributed"
        case .borrowing: return "borrowing"
        case .consuming: return "consuming"
        case .prefix: return "prefix"
        case .infix: return "infix"
        case .postfix: return "postfix"
        case .unknown(let keyword): return keyword
        }
    }
}

extension SwiftModifier: CustomStringConvertible {
    public var description: String { rawValue }
}
