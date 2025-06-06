//
//  Assertions.swift
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

/// Extension to add assertion methods to collections of declarations
extension Collection where Element: SwiftDeclaration {
    /// Assert that all elements match the given predicate
    public func assertTrue(predicate: (Element) -> Bool) -> Bool {
        return self.allSatisfy(predicate)
    }

    /// Assert that all elements do not match the given predicate
    public func assertFalse(predicate: (Element) -> Bool) -> Bool {
        return self.allSatisfy { !predicate($0) }
    }

    /// Assert that collection count matches give count
    public func assertCount(_ count: Int) -> Bool {
        return self.count == count
    }

    /// Assert that colleciton is empty
    public func assertEmpty() -> Bool {
        return self.isEmpty
    }

    /// Assert that colleciton is not empty
    public func assertNotEmpty() -> Bool {
        return !self.isEmpty
    }
}
