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
    public func assertArchitecture(_ defineRules: (ArchitectureRules) -> Void) -> Bool {
        let ruleSet = ArchitectureRules()
        defineRules(ruleSet)

        var context = ArchitectureRuleContext(
            scope: self,
            declarations: self.declarations(),
            layers: Array(ruleSet.layers.values)
        )

        var allPassed = true
        for rule in ruleSet.rules {
            if !rule.check(context: &context) {
                allPassed = false

                print("Rule Failed: \(rule.ruleDescription)")
                for violation in rule.violations {
                    print("  \(violation.detail) in \(violation.sourceDeclaration.name) at \(violation.sourceDeclaration.filePath):\(violation.sourceDeclaration.location.line)")
                }
            }
        }
        return allPassed
    }
} 
