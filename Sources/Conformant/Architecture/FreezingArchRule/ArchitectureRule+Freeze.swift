//
//  ArchitectureRule+Freeze.swift
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

extension ArchitectureRule {
    /// Creates a freezing version of this rule
    /// - Parameters:
    ///   - violationStore: The store for violations
    ///   - lineMatcher: The matcher for comparing violations
    /// - Returns: A freezing architecture rule that wraps this rule
    public func freeze(using violationStore: ViolationStore,
                       matching lineMatcher: ViolationLineMatcher = DefaultViolationLineMatcher()) -> FreezingArchRule {
        return FreezingArchRule(rule: self, violationStore: violationStore, lineMatcher: lineMatcher)
    }

    /// Creates a freezing version of this rule using a file-based violation store
    /// - Parameter filePath: The path to the JSON file where violations will be stored
    /// - Returns: A freezing architecture rule that wraps this rule
    public func freeze(toFile filePath: String) -> FreezingArchRule {
        let store = FileViolationStore(filePath: filePath)
        return FreezingArchRule(rule: self, violationStore: store)
    }
}
