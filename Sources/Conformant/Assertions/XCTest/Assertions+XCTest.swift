//
//  Assertions+XCTest.swift
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

#if canImport(XCTest)
import XCTest

/// Extension to add assertion methods to collections of declarations
extension Collection where Element: SwiftDeclaration {
    /// Assert that all elements match the given predicate
    public func assertTrue(message: String = "", file: StaticString = #filePath, line: UInt = #line, predicate: (Element) -> Bool) {
        XCTAssertTrue(self.assertTrue(predicate: predicate), message, file: file, line: line)
    }

    /// Assert that all elements do not match the given predicate
    public func assertFalse(message: String = "", file: StaticString = #filePath, line: UInt = #line, predicate: (Element) -> Bool) {
        XCTAssertTrue(self.assertFalse(predicate: predicate), message, file: file, line: line)
    }

    /// Assert that colleciton count matches give count
    public func assertCount(message: String = "", file: StaticString = #filePath, line: UInt = #line, count: Int) {
        XCTAssertTrue(self.assertCount(count), message, file: file, line: line)
    }

    /// Assert that colleciton is empty
    public func assertEmpty(message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(self.assertEmpty(), message, file: file, line: line)
    }

    /// Assert that colleciton is not empty
    public func assertNotEmpty(message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(self.assertNotEmpty(), message, file: file, line: line)
    }

    /// Run architecture rules as test assertions
    /// - Parameter defineRules: Block that defines architecture rules to validate
    /// - Returns: Whether all rules passed
    public func assertArchitecture(_ defineRules: (ArchitectureRules) -> Void,
                            file: StaticString = #filePath,
                            line: UInt = #line) -> Bool {
        let ruleSet = ArchitectureRules()
        defineRules(ruleSet)

        let spec = Conformant.scopeFromProject()
        var context = ArchitectureRuleContext(
            scope: spec,
            declarations: spec.declarations(),
            layers: Array(ruleSet.layers.values)
        )

        var allPassed = true
        for rule in ruleSet.rules {
            if !rule.check(context: &context) {
                allPassed = false

                for violation in rule.violations {
                    let message = """
                    Rule Failed: \(rule.ruleDescription)
                    Violation: \(violation.detail)
                    In: \(violation.sourceDeclaration.name)
                    At: \(violation.sourceDeclaration.filePath):\(violation.sourceDeclaration.location.line)
                    """
                    XCTFail(message, file: file, line: line)
                }
            }
        }

        return allPassed
    }
}
#endif
