//
//  ParseError.swift
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

public enum ParseError: Error, CustomStringConvertible {
    case packageInitializerNotFound
    case packageInitializerNotClosed
    case missingRequiredParameter(String)
    case malformedStringLiteral
    case malformedArrayLiteral
    case malformedParameter(String)
    case unexpectedSyntax(String)

    public var description: String {
        switch self {
        case .packageInitializerNotFound: return "Could not find 'Package(' initializer."
        case .packageInitializerNotClosed: return "Could not find matching ')' for 'Package(' initializer."
        case .missingRequiredParameter(let name): return "Missing required package parameter: '\(name)'."
        case .malformedStringLiteral: return "Malformed string literal found."
        case .malformedArrayLiteral: return "Malformed array literal '[]' found."
        case .malformedParameter(let label): return "Malformed parameter syntax for '\(label)'."
        case .unexpectedSyntax(let context): return "Unexpected syntax encountered near: \(context)"
        }
    }
}
