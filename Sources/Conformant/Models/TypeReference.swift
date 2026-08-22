//
//  TypeReference.swift
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

/// A single named type as it was *written* in the source.
///
/// The parser has no type checker, so a `TypeReference` records syntax, not semantics.
/// `Swift.Int` is one reference whose `qualifiedName` is `"Swift.Int"` — it is never
/// split into `Swift` and `Int`, and nothing here resolves `Int` to the standard library
/// or `Entity.ID` to a concrete type.
public struct TypeReference: Hashable, Sendable {

    /// The syntactic position a reference was written in.
    ///
    /// Sugar (`T?`, `[T]`, `[K: V]`) does not produce a reference of its own; it sets the
    /// form of what it wraps, so `[UserProfile]` is one `.array` reference to
    /// `UserProfile` rather than a reference to `Array` plus a reference to `UserProfile`.
    public enum Form: String, Hashable, Sendable, CaseIterable {
        /// Written directly: `UserProfile`, `Result<Data, Error>`.
        case plain
        /// `T?` or `T!`.
        case optional
        /// `[T]`.
        case array
        /// `[Key: Value]` — both the key and the value carry this form.
        case dictionary
        /// A parameter or return type of a function type: `(Request) -> Response`.
        case function
        /// An element of a tuple type: `(Int, String)`.
        case tuple
        /// `any P`.
        case existential
        /// `some P`, including the named form `<T> T`.
        case opaque
        /// The base of `T.Type` or `T.Protocol`.
        case metatype
        /// A member of a parameter pack: `repeat each T`, `each T`.
        case pack
        /// A member of a protocol composition: `A & B`.
        case composition
        /// The base of a suppressed conformance: `~Copyable`.
        case suppressed
    }

    /// The last component of the written name — `Int` in `Swift.Int`, `ID` in `Entity.ID`.
    public let baseName: String

    /// The name exactly as written, dots included — `Swift.Int`, `Entity.ID`, `Int`.
    public let qualifiedName: String

    /// The leftmost component of a dotted name, or `nil` when the name has no dot.
    ///
    /// Named for the common case. Without a type checker there is no way to tell the
    /// module `Foundation` in `Foundation.URL` from the enclosing type `Outer` in
    /// `Outer.Inner` or the associated type `Entity` in `Entity.ID`.
    public let moduleQualifier: String?

    /// The arguments of an explicit generic clause: `Data` and `NetworkError` in
    /// `Result<Data, NetworkError>`. Empty for sugar — `[T]` records `T` as the
    /// reference itself, not as an argument of `Array`.
    public let genericArguments: [TypeReference]

    /// Where in the written type this reference appeared.
    public let form: Form

    public init(
        baseName: String,
        qualifiedName: String,
        moduleQualifier: String? = nil,
        genericArguments: [TypeReference] = [],
        form: Form = .plain
    ) {
        self.baseName = baseName
        self.qualifiedName = qualifiedName
        self.moduleQualifier = moduleQualifier
        self.genericArguments = genericArguments
        self.form = form
    }

    /// The identifier a name is rooted at: the qualifier when there is one, the base name
    /// otherwise. This is the name that a generic parameter or `associatedtype` in scope
    /// can shadow — `Entity` binds `Entity.ID`, not just `Entity`.
    public var rootName: String {
        moduleQualifier ?? baseName
    }

    /// This reference followed by every reference nested in its generic arguments,
    /// depth first. `Result<Data, [Failure]>` flattens to `Result`, `Data`, `Failure`.
    public var flattened: [TypeReference] {
        [self] + genericArguments.flatMap(\.flattened)
    }

    /// Whether this names a type or protocol that ships with the Swift standard library.
    ///
    /// Deliberately a fixed list rather than a lookup: the parser resolves nothing, so
    /// a local `struct Result` is indistinguishable from `Swift.Result` and both answer
    /// `true`. Used only by the opt-in `ScopePolicy.ignoresStandardLibraryTypes` filter.
    public var isStandardLibraryType: Bool {
        if moduleQualifier == "Swift" { return true }
        return moduleQualifier == nil && Self.standardLibraryNames.contains(baseName)
    }

    private static let standardLibraryNames: Set<String> = [
        // Values
        "Bool", "Character", "Double", "Float", "Float16", "Float80",
        "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "String", "Substring", "StaticString", "Unicode", "Never", "Void",
        // Containers
        "Array", "ArraySlice", "ContiguousArray", "Dictionary", "Set", "Slice",
        "Optional", "Result", "KeyValuePairs", "EmptyCollection", "Repeated", "Zip2Sequence",
        "Range", "ClosedRange", "PartialRangeFrom", "PartialRangeThrough", "PartialRangeUpTo",
        "AnyIterator", "AnySequence", "AnyCollection", "AnyBidirectionalCollection",
        "AnyRandomAccessCollection", "IndexingIterator", "ReversedCollection",
        // Any-erasers and pointers
        "AnyObject", "AnyHashable", "AnyKeyPath", "KeyPath", "WritableKeyPath",
        "ReferenceWritableKeyPath", "PartialKeyPath", "ObjectIdentifier", "Mirror",
        "UnsafePointer", "UnsafeMutablePointer", "UnsafeRawPointer",
        "UnsafeMutableRawPointer", "UnsafeBufferPointer", "UnsafeMutableBufferPointer",
        "UnsafeRawBufferPointer", "UnsafeMutableRawBufferPointer", "OpaquePointer",
        "Unmanaged", "MemoryLayout",
        // Protocols
        "Equatable", "Hashable", "Comparable", "Identifiable", "CaseIterable",
        "Codable", "Encodable", "Decodable", "Encoder", "Decoder",
        "Error", "LocalizedError", "Sendable", "Copyable", "Escapable", "Actor", "AnyActor",
        "RawRepresentable", "ExpressibleByNilLiteral", "ExpressibleByStringLiteral",
        "ExpressibleByIntegerLiteral", "ExpressibleByArrayLiteral",
        "ExpressibleByDictionaryLiteral", "ExpressibleByBooleanLiteral",
        "CustomStringConvertible", "CustomDebugStringConvertible", "TextOutputStream",
        "Sequence", "IteratorProtocol", "Collection", "BidirectionalCollection",
        "RandomAccessCollection", "MutableCollection", "RangeReplaceableCollection",
        "Strideable", "Numeric", "SignedNumeric", "BinaryInteger", "FixedWidthInteger",
        "SignedInteger", "UnsignedInteger", "BinaryFloatingPoint", "FloatingPoint",
        "Hasher", "AsyncSequence", "AsyncIteratorProtocol", "AsyncStream", "AsyncThrowingStream",
        "Task", "TaskGroup", "ThrowingTaskGroup", "MainActor", "GlobalActor",
    ]

    /// Whether `name` names this reference.
    ///
    /// Matches the written name exactly, or any suffix of it that starts at a component
    /// boundary — so a reference to `MyModule.Deep.Type1` answers to `MyModule.Deep.Type1`,
    /// `Deep.Type1`, and `Type1`, but not to `Type` or `Deep`.
    public func matches(_ name: String) -> Bool {
        qualifiedName == name || qualifiedName.hasSuffix(".\(name)")
    }
}
