//
//  BuildConfiguration.swift
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

/// A description of the build a scope is read for, used to decide which `#if` branches
/// are live.
///
/// Conformant does not compile anything, so it cannot discover any of this on its own: a
/// file that says `#if os(iOS)` means one thing on an iOS build and another on a macOS
/// one, and nothing in the source says which build is intended. A configuration is how a
/// test states the build it is asking about.
///
/// Every field is optional, and a predicate the configuration cannot answer leaves *both*
/// branches in the scope. That is the safe direction: a rule evaluated against
/// declarations that were wrongly dropped would pass by having nothing to check, while one
/// evaluated against a branch that will never compile can only report too much.
///
/// ```swift
/// var policy = ScopePolicy.strict
/// policy.conditionalCompilation = .activeBranch(
///     BuildConfiguration(operatingSystem: "iOS", customFlags: ["DEBUG"],
///                        importableModules: ["UIKit", "Foundation"])
/// )
/// ```
public struct BuildConfiguration: Hashable, Sendable {

    /// The `os(...)` argument this build matches: `"iOS"`, `"macOS"`, `"Linux"`.
    /// `nil` leaves every `os(...)` test undecided.
    public var operatingSystem: String?

    /// The `arch(...)` argument this build matches: `"arm64"`, `"x86_64"`.
    public var architecture: String?

    /// The `targetEnvironment(...)` argument this build matches: `"simulator"`,
    /// `"macCatalyst"`. `nil` leaves every `targetEnvironment(...)` test undecided rather
    /// than answering "device": a device build is itself a statement about the build.
    public var targetEnvironment: String?

    /// The language version `swift(>=...)` is compared against, written as it is in
    /// source: `"6.0"`, `"5.9.1"`.
    public var swiftVersion: String?

    /// The compiler version `compiler(>=...)` is compared against.
    public var compilerVersion: String?

    /// The flags this build defines with `-D`.
    ///
    /// Unlike the other fields, a flag that is *not* listed reads as unset rather than
    /// unknown: the compiler knows its whole `-D` set, and so does whoever writes this
    /// configuration. `#if DEBUG` is therefore dropped by a configuration that does not
    /// name `DEBUG`, which is the point, and a misspelled flag drops code that should have
    /// been read. Spell them the way the build does.
    public var customFlags: Set<String>

    /// The modules `canImport(...)` answers yes for.
    ///
    /// `nil`, the default, means the answer is unknown, so both branches of
    /// `#if canImport(UIKit)` stay in the scope. Conformant reads source; it has no module
    /// map and cannot find out.
    public var importableModules: Set<String>?

    public init(
        operatingSystem: String? = nil,
        architecture: String? = nil,
        targetEnvironment: String? = nil,
        swiftVersion: String? = nil,
        compilerVersion: String? = nil,
        customFlags: Set<String> = [],
        importableModules: Set<String>? = nil
    ) {
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.targetEnvironment = targetEnvironment
        self.swiftVersion = swiftVersion
        self.compilerVersion = compilerVersion
        self.customFlags = customFlags
        self.importableModules = importableModules
    }
}
