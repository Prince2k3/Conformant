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

    public init(
        onSyntaxError: Reaction = .fail,
        onUnreadableFile: Reaction = .fail,
        onEmptyScope: Reaction = .fail
    ) {
        self.onSyntaxError = onSyntaxError
        self.onUnreadableFile = onUnreadableFile
        self.onEmptyScope = onEmptyScope
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
