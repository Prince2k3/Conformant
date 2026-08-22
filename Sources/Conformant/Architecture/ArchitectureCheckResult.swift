//
//  ArchitectureCheckResult.swift
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

/// The outcome of evaluating a set of architecture rules against a scope.
///
/// Rule evaluation used to `print` its failures and return a bare `Bool`, which meant the
/// detail was invisible to anything but a human watching the console. The messages are
/// carried on the result instead, so a test can report them.
public struct ArchitectureCheckResult: Sendable {
    /// Problems with the scope itself — it was empty, or files in it failed to parse.
    ///
    /// These are reported separately because they invalidate the run: rules evaluated
    /// against a scope that holds nothing all pass, which looks identical to success.
    public let scopeProblems: [String]

    /// One message per rule violation.
    public let violations: [String]

    public init(scopeProblems: [String], violations: [String]) {
        self.scopeProblems = scopeProblems
        self.violations = violations
    }

    /// `true` only when the scope was usable *and* every rule held.
    public var passed: Bool {
        scopeProblems.isEmpty && violations.isEmpty
    }

    /// Scope problems first — a violation list produced from a broken scope is not
    /// trustworthy, so the reason the run is invalid should be read before the findings.
    public var messages: [String] {
        scopeProblems + violations
    }

    public var description: String {
        passed ? "All architecture rules passed." : messages.joined(separator: "\n\n")
    }
}
