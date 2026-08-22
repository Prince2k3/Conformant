//
//  PatternCache.swift
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

/// Compiled regexes, kept so that the same pattern is only built once.
///
/// The patterns that filters and layer rules match against are written as arguments —
/// `resideInPackage("..Networking..")`, `withName(matching: "^Mock")` — so they cannot be
/// compiled where the rule is constructed. Without a cache, asking a thousand declarations
/// whether they reside in a package compiles the same pattern a thousand times, and
/// compiling costs far more than matching.
///
/// Failures are cached too: an invalid pattern is invalid every time, and re-deriving that
/// is as expensive as the successful case. Callers still decide what to do about it, so the
/// error travels back with the result rather than being swallowed here.
///
/// Patterns come from rule and test source, so the cache holds one entry per pattern an
/// author wrote — a bounded set that never grows during a run.
enum PatternCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var compiled: [String: Result<Regex<AnyRegexOutput>, any Error>] = [:]

    /// The compiled form of `pattern`, or the error that compiling it produced.
    static func compile(_ pattern: String) -> Result<Regex<AnyRegexOutput>, any Error> {
        lock.lock()
        defer { lock.unlock() }

        if let existing = compiled[pattern] { return existing }

        let result = Result { try Regex(pattern) }
        compiled[pattern] = result
        return result
    }
}
