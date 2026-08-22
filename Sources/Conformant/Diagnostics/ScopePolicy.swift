//
//  ScopePolicy.swift
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

/// Controls what Conformant does when it cannot fully see the code it was asked about.
///
/// The default is `.strict`, because this is a testing library: a scope that silently
/// shrinks turns a failing rule into a passing test, which is the one failure mode a
/// test tool must not have. `.lenient` restores the previous best-effort behavior for
/// callers scanning codebases they do not control.
public struct ScopePolicy: Sendable {

    /// What to do when a condition is met.
    public enum Reaction: String, Sendable {
        /// Throw a `ConformantError`.
        case fail
        /// Record a diagnostic on the scope and continue.
        case warn
        /// Proceed as if nothing happened.
        case ignore
    }

    /// A file contained syntax errors. Its declarations are partial.
    public var onSyntaxError: Reaction

    /// A file or directory could not be read.
    public var onUnreadableFile: Reaction

    /// The scope resolved to zero Swift files.
    public var onEmptyScope: Reaction

    /// How much of a declaration counts as a dependency.
    public enum DependencyDepth: String, Sendable {
        /// Only what a declaration writes down in its signature: inheritance,
        /// conformances, parameter and return types, property annotations.
        case signatures
        /// Also what its bodies reach for — types they construct, static members they
        /// touch, and types they name in annotations, casts, and generic arguments.
        case signaturesAndBodies
    }

    /// Whether bodies are read for dependencies. Defaults to `.signaturesAndBodies`.
    ///
    /// Bodies are strictly more information, so turning this off can only make a rule
    /// easier to satisfy: with `.signatures`, a type that constructs a `UserRepository`
    /// in every method still passes `dependsOnNothing()`. The switch exists because
    /// reading bodies surfaces coupling that existing suites were passing over, not
    /// because hiding it is the safer default.
    public var dependencyDepth: DependencyDepth

    /// Drop references to standard library types (`Int`, `String`, `Hashable`, …) from
    /// every declaration's dependency list.
    ///
    /// Off by default, and deliberately so. Removing dependencies can only make a rule
    /// easier to satisfy: with this on, a type whose only dependency is `String` passes
    /// `dependsOnNothing()`. Turn it on when you are reading dependency lists and the
    /// standard library is drowning out the types you care about; leave it off when the
    /// lists feed architecture rules.
    public var ignoresStandardLibraryTypes: Bool

    public init(
        onSyntaxError: Reaction = .fail,
        onUnreadableFile: Reaction = .fail,
        onEmptyScope: Reaction = .fail,
        dependencyDepth: DependencyDepth = .signaturesAndBodies,
        ignoresStandardLibraryTypes: Bool = false
    ) {
        self.onSyntaxError = onSyntaxError
        self.onUnreadableFile = onUnreadableFile
        self.onEmptyScope = onEmptyScope
        self.dependencyDepth = dependencyDepth
        self.ignoresStandardLibraryTypes = ignoresStandardLibraryTypes
    }

    /// Any problem fails the scope. The default, and the right choice inside a test suite.
    public static let strict = ScopePolicy()

    /// Problems are recorded on the scope but do not throw. Inspect `scope.diagnostics`.
    /// Useful when auditing a codebase that is expected to contain unparseable files.
    public static let warning = ScopePolicy(
        onSyntaxError: .warn,
        onUnreadableFile: .warn,
        onEmptyScope: .warn
    )

    /// Best-effort scanning: problems are neither reported nor thrown. This reproduces
    /// the behavior of the deprecated `scopeFromProject` / `scopeFromDirectory` /
    /// `scopeFromFile` entry points.
    public static let lenient = ScopePolicy(
        onSyntaxError: .ignore,
        onUnreadableFile: .ignore,
        onEmptyScope: .ignore
    )
}
