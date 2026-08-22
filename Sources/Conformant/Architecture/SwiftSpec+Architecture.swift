//
//  SwiftSpec+Architecture.swift
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

/// Extension to add architecture verification to SwiftScope
extension Conformant {
    /// Evaluates architecture rules and returns every failure it found.
    ///
    /// The scope is validated before any rule runs: an empty scope, or one holding files
    /// that failed to parse, is reported as a scope problem rather than as a pass. Rules
    /// only ever *look* satisfied against declarations that were never read.
    public func checkArchitecture(_ defineRules: (ArchitectureRules) -> Void) -> ArchitectureCheckResult {
        var scopeProblems: [String] = []

        if isEmpty {
            scopeProblems.append(
                "Conformant: the scope contains no Swift files. Every architecture rule "
                + "passes against an empty scope, so this is reported as a failure rather "
                + "than a pass. Check the path the scope was built from."
            )
        }

        let errors = diagnostics.errors
        if !errors.isEmpty {
            scopeProblems.append(
                "Conformant: \(errors.count) file(s) in the scope failed to parse. "
                + "Declarations in them are missing, so rule results are incomplete.\n"
                + errors.summary()
            )
        }

        guard scopeProblems.isEmpty else {
            return ArchitectureCheckResult(scopeProblems: scopeProblems, violations: [])
        }

        let ruleSet = ArchitectureRules()
        defineRules(ruleSet)

        var context = ArchitectureRuleContext(
            scope: self,
            declarations: self.declarations(),
            layers: ruleSet.layers
        )

        var violations: [String] = []
        for rule in ruleSet.rules where !rule.check(context: &context) {
            for violation in rule.violations {
                violations.append("""
                Rule Failed: \(rule.ruleDescription)
                Violation: \(violation.detail)
                In: \(violation.sourceDeclaration.name)
                At: \(violation.sourceDeclaration.filePath):\(violation.sourceDeclaration.location.line)
                """)
            }
        }

        return ArchitectureCheckResult(scopeProblems: [], violations: violations)
    }

    /// Evaluates architecture rules and reports whether all of them held.
    ///
    /// Use ``checkArchitecture(_:)`` when the failure detail matters.
    public func assertArchitecture(_ defineRules: (ArchitectureRules) -> Void) -> Bool {
        checkArchitecture(defineRules).passed
    }
}
