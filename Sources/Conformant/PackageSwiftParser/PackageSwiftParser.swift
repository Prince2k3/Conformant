//
//  PackageSwiftParser.swift
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
import RegexBuilder

/// A modern parser for Package.swift files using Swift's RegEx framework and sequential parsing
public struct PackageSwiftParser {
    private let originalContent: String

    /// Initialize with the content of a Package.swift file
    public init(content: String) {
        self.originalContent = content
    }

    /// Initialize with the URL of a Package.swift file
    public init(url: URL) throws {
        self.originalContent = try String(contentsOf: url)
    }

    /// Initialize with the path of a Package.swift file
    public init(path: String) throws {
        let url = URL(fileURLWithPath: path)
        try self.init(url: url)
    }

    /// Parse the Package.swift file sequentially and return a Package object
    public func parse() throws -> Package {
        guard let packageInitRange = originalContent.firstRange(of: /Package\s*\(/) else {
            throw ParseError.packageInitializerNotFound
        }

        let contentToParse = originalContent[packageInitRange.upperBound...]

        guard let packageEndIndex = findMatchingParenthesis(in: contentToParse) else {
            throw ParseError.packageInitializerNotClosed
        }

        var currentSubstring = contentToParse[..<packageEndIndex]

        var name: String? = nil
        var platforms: [Package.Platform] = []
        var products: [Package.Product] = []
        var dependencies: [Package.Dependency] = []
        var targets: [Package.Target] = []
        var swiftLanguageVersions: [String] = []
        var cLanguageStandard: String? = nil
        var cxxLanguageStandard: String? = nil

        while !currentSubstring.isEmpty {
            // Skip leading whitespace and commas
            currentSubstring = currentSubstring.trimmingPrefix { $0.isWhitespace || $0 == "," }
            if currentSubstring.isEmpty { break }

            if currentSubstring.hasPrefix("//") {
                if let newlineIndex = currentSubstring.firstIndex(of: "\n") {
                    currentSubstring = currentSubstring[currentSubstring.index(after: newlineIndex)...]
                    continue
                } else {
                    break // Comment runs to the end of the string
                }
            } else if currentSubstring.hasPrefix("/*") {
                if let endCommentIndex = currentSubstring.range(of: "*/")?.upperBound {
                    currentSubstring = currentSubstring[endCommentIndex...]
                    continue
                } else {
                    break // Unclosed comment
                }
            }

            currentSubstring = currentSubstring.trimmingPrefix { $0.isWhitespace || $0 == "," }
            if currentSubstring.isEmpty { break }

            if currentSubstring.starts(with: "name:") {
                let parseResult = try parseStringParameter(label: "name", from: currentSubstring)
                name = parseResult.value
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "platforms:") {
                let parseResult = try parseArrayParameter(label: "platforms", from: currentSubstring)
                platforms = extractPlatforms(from: parseResult.content)
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "products:") {
                let parseResult = try parseArrayParameter(label: "products", from: currentSubstring)
                products = extractProducts(from: parseResult.content)
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "dependencies:") {
                let parseResult = try parseArrayParameter(label: "dependencies", from: currentSubstring)
                dependencies = extractDependencies(from: parseResult.content)
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "targets:") {
                let parseResult = try parseArrayParameter(label: "targets", from: currentSubstring)
                targets = extractTargets(from: parseResult.content)
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "swiftLanguageVersions:") {
                let parseResult = try parseArrayParameter(label: "swiftLanguageVersions", from: currentSubstring)
                swiftLanguageVersions = extractSwiftLanguageVersions(from: parseResult.content)
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "cLanguageStandard:") {
                let parseResult = try parseLanguageStandardParameter(label: "cLanguageStandard", from: currentSubstring)
                cLanguageStandard = parseResult.value
                currentSubstring = parseResult.remaining
            } else if currentSubstring.starts(with: "cxxLanguageStandard:") {
                let parseResult = try parseLanguageStandardParameter(label: "cxxLanguageStandard", from: currentSubstring)
                cxxLanguageStandard = parseResult.value
                currentSubstring = parseResult.remaining
            } else if let nextParamIndex = findNextParameterOrComma(in: currentSubstring) {
                currentSubstring = currentSubstring[nextParamIndex...]
            } else {
                break
            }
        }

        guard let finalName = name else {
            throw ParseError.missingRequiredParameter("name")
        }

        return Package(
            name: finalName,
            platforms: platforms,
            products: products,
            dependencies: dependencies,
            targets: targets,
            swiftLanguageVersions: swiftLanguageVersions,
            cLanguageStandard: cLanguageStandard,
            cxxLanguageStandard: cxxLanguageStandard
        )
    }

    // MARK: - Sequential Parsing Helpers

    /// Finds the index of the matching closing parenthesis for an opening one at the start.
    private func findMatchingParenthesis(in substring: Substring) -> Substring.Index? {
        var depth = 1
        var currentIndex = substring.startIndex
        var inSingleLineComment = false
        var inMultiLineComment = false

        while currentIndex < substring.endIndex {
            let char = substring[currentIndex]

            if !inSingleLineComment && !inMultiLineComment {
                if char == "/" && currentIndex < substring.index(before: substring.endIndex) {
                    let nextIndex = substring.index(after: currentIndex)
                    let nextChar = substring[nextIndex]

                    if nextChar == "/" {
                        inSingleLineComment = true
                        currentIndex = substring.index(after: nextIndex)
                        continue
                    } else if nextChar == "*" {
                        inMultiLineComment = true
                        currentIndex = substring.index(after: nextIndex)
                        continue
                    }
                }

                if char == "(" {
                    depth += 1
                } else if char == ")" {
                    depth -= 1
                    if depth == 0 {
                        return currentIndex
                    }
                } else if char == "\"" {
                    currentIndex = substring.index(after: currentIndex)
                    while currentIndex < substring.endIndex && substring[currentIndex] != "\"" {
                        if substring[currentIndex] == "\\" && currentIndex < substring.index(before: substring.endIndex) {
                            currentIndex = substring.index(after: currentIndex) // Skip the escaped character
                        }
                        currentIndex = substring.index(after: currentIndex)
                    }

                    if currentIndex >= substring.endIndex {
                        return nil
                    }
                }
            } else if inSingleLineComment {
                if char == "\n" {
                    inSingleLineComment = false
                }
            } else if inMultiLineComment {
                if char == "*" && currentIndex < substring.index(before: substring.endIndex) {
                    let nextIndex = substring.index(after: currentIndex)
                    if substring[nextIndex] == "/" {
                        inMultiLineComment = false
                        currentIndex = nextIndex
                    }
                }
            }

            if currentIndex < substring.index(before: substring.endIndex) {
                currentIndex = substring.index(after: currentIndex)
            } else {
                break
            }
        }

        return nil
    }

    /// Finds the index of the matching closing bracket for an opening one at the start.
    private func findMatchingBracket(in substring: Substring) -> Substring.Index? {
        var depth = 1 // Assumes the opening bracket was just consumed
        var currentIndex = substring.startIndex
        var inSingleLineComment = false
        var inMultiLineComment = false

        while currentIndex < substring.endIndex {
            let char = substring[currentIndex]

            if !inSingleLineComment && !inMultiLineComment {
                if char == "/" && currentIndex < substring.index(before: substring.endIndex) {
                    let nextIndex = substring.index(after: currentIndex)
                    let nextChar = substring[nextIndex]

                    if nextChar == "/" {
                        inSingleLineComment = true
                        currentIndex = substring.index(after: nextIndex)
                        continue
                    } else if nextChar == "*" {
                        inMultiLineComment = true
                        currentIndex = substring.index(after: nextIndex)
                        continue
                    }
                }

                if char == "[" {
                    depth += 1
                } else if char == "]" {
                    depth -= 1
                    if depth == 0 {
                        return currentIndex
                    }
                } else if char == "\"" {
                    currentIndex = substring.index(after: currentIndex)

                    while currentIndex < substring.endIndex && substring[currentIndex] != "\"" {
                        if substring[currentIndex] == "\\" && currentIndex < substring.index(before: substring.endIndex) {
                            currentIndex = substring.index(after: currentIndex) // Skip the escaped character
                        }
                        currentIndex = substring.index(after: currentIndex)
                    }

                    if currentIndex >= substring.endIndex {
                        return nil
                    }
                } else if char == "(" {
                    currentIndex = substring.index(after: currentIndex)
                    let remainingSubstring = substring[currentIndex...]
                    if let matchingParenIndex = findMatchingParenthesis(in: remainingSubstring) {
                        currentIndex = matchingParenIndex
                    } else {
                        return nil
                    }
                }
            } else if inSingleLineComment {
                if char == "\n" {
                    inSingleLineComment = false
                }
            } else if inMultiLineComment {
                if char == "*" && currentIndex < substring.index(before: substring.endIndex) {
                    let nextIndex = substring.index(after: currentIndex)
                    if substring[nextIndex] == "/" {
                        inMultiLineComment = false
                        currentIndex = nextIndex
                    }
                }
            }

            if currentIndex < substring.index(before: substring.endIndex) {
                currentIndex = substring.index(after: currentIndex)
            } else {
                break
            }
        }

        return nil
    }


    /// Parses a parameter expecting a string literal value (e.g., name: "...")
    private func parseStringParameter(label: String, from substring: Substring) throws -> (value: String, remaining: Substring) {
        var localSubstring = substring
        guard let colonIndex = localSubstring.firstIndex(of: ":") else {
            throw ParseError.malformedParameter(label)
        }

        localSubstring = localSubstring[localSubstring.index(after: colonIndex)...].lstrip() // lstrip removes leading whitespace

        guard localSubstring.first == "\"" else { throw ParseError.malformedStringLiteral }
        localSubstring = localSubstring.dropFirst()

        guard let closingQuoteIndex = localSubstring.firstIndex(of: "\"") else {
            throw ParseError.malformedStringLiteral
        }

        let value = String(localSubstring[..<closingQuoteIndex])
        let remaining = localSubstring[localSubstring.index(after: closingQuoteIndex)...]

        return (value, remaining)
    }

    /// Parses a parameter expecting an array literal value (e.g., platforms: [...])
    /// Returns the inner content of the array and the remaining substring.
    private func parseArrayParameter(label: String, from substring: Substring) throws -> (content: Substring, remaining: Substring) {
        var localSubstring = substring

        guard let colonIndex = localSubstring.firstIndex(of: ":") else {
            throw ParseError.malformedParameter(label)
        }

        localSubstring = localSubstring[localSubstring.index(after: colonIndex)...].lstrip()

        guard localSubstring.first == "[" else { throw ParseError.malformedArrayLiteral }
        let arrayStartIndex = localSubstring.index(after: localSubstring.startIndex)
        localSubstring = localSubstring[arrayStartIndex...]

        guard let closingBracketIndex = findMatchingBracket(in: localSubstring) else {
            throw ParseError.malformedArrayLiteral
        }

        let content = localSubstring[..<closingBracketIndex]
        let remaining = localSubstring[localSubstring.index(after: closingBracketIndex)...]

        return (content, remaining)
    }

    /// Parses a parameter expecting a language standard (e.g., .c11 or "gnu99")
    private func parseLanguageStandardParameter(label: String, from substring: Substring) throws -> (value: String?, remaining: Substring) {
        var localSubstring = substring
        guard let colonIndex = localSubstring.firstIndex(of: ":") else {
            throw ParseError.malformedParameter(label)
        }

        localSubstring = localSubstring[localSubstring.index(after: colonIndex)...].lstrip()

        var value: String?
        var remaining = localSubstring

        // Check for dot notation (e.g., .c11, .gnu11)
        if localSubstring.starts(with: ".") {
            if let match = localSubstring.prefixMatch(of: /^\.([a-zA-Z0-9]+)/) {
                value = String(match.1)
                remaining = localSubstring[match.range.upperBound...]
            } else {
                throw ParseError.malformedParameter(label) // Found dot but couldn't parse standard
            }
        }
        // Check for quoted string notation (e.g., "c11")
        else if localSubstring.starts(with: "\"") {
            if let closingQuoteIndex = localSubstring.dropFirst().firstIndex(of: "\"") {
                value = String(localSubstring[localSubstring.index(after: localSubstring.startIndex)..<closingQuoteIndex])
                remaining = localSubstring[localSubstring.index(after: closingQuoteIndex)...]
            } else {
                throw ParseError.malformedStringLiteral
            }
        }
        // Add cases for other potential formats if needed
        else {
            // Could be nil or just not present, or malformed.
            // Let's assume if it's not dot or quote, it's just not set correctly here.
            // We need to determine how far to advance 'remaining'. This part is tricky.
            // For now, let's assume it means the parameter wasn't actually present in a recognizable format.
            // A safer approach might be to find the next comma or closing parenthesis.
            if let nextCommaOrParen = localSubstring.firstIndex(where: { $0 == "," || $0 == ")" }) {
                remaining = localSubstring[nextCommaOrParen...]
                value = nil
            } else {
                // Reached end without comma/paren? Likely end of Package() block.
                remaining = localSubstring[localSubstring.endIndex...]
                value = nil
            }
        }

        return (value, remaining)
    }

    private func extractPlatforms(from arrayContent: Substring) -> [Package.Platform] {
        var platforms: [Package.Platform] = []
        // Use the helper to split array content like "[.macOS(.v12), .iOS(.v15)]" into entries
        let platformEntries = splitBlockIntoEntries(String(arrayContent))

        for entry in platformEntries {
            // Define a regex to capture the platform name and the raw content inside the version parentheses
            // Example entry: ".macOS(.v12)"
            let platformPattern = Regex {
                "."
                Capture {
                    OneOrMore(.word)
                }
                ZeroOrMore(.whitespace)
                "("
                ZeroOrMore(.whitespace)
                Capture {
                    ZeroOrMore(.any, .reluctant)
                }
                ZeroOrMore(.whitespace)
                ")"
            }

            if let match = entry.firstMatch(of: platformPattern) {
                let name = String(match.1)
                let versionContent = String(match.2).trimmingCharacters(in: .whitespaces)

                var version: String? = nil

                if versionContent.starts(with: ".v") {
                    let versionPart = versionContent.dropFirst(".v".count)
                    version = String(versionPart).replacingOccurrences(of: "_", with: ".")
                } else if versionContent.starts(with: ".version") {
                    let versionStringPattern = Regex {
                        ".version"
                        ZeroOrMore(.whitespace)
                        "("
                        ZeroOrMore(.whitespace)
                        "\""
                        Capture {
                            OneOrMore(.anyNonNewline.subtracting(.anyOf("\"")))
                        }
                        "\""
                        ZeroOrMore(.whitespace)
                        ")"
                        ZeroOrMore(.whitespace)
                    }
                    if let versionMatch = versionContent.firstMatch(of: versionStringPattern) {
                        version = String(versionMatch.1)
                    }
                }
                // Add checks for other possible version formats here if needed

                // --- Append platform if version was successfully parsed ---
                if let finalVersion = version {
                    platforms.append(Package.Platform(name: name, version: finalVersion))
                } else {
                    // Log a warning if the version format inside the parentheses wasn't recognized
                    print("Warning: Could not parse version from platform entry: \(entry)")
                }
            } else {
                // Log a warning if the overall entry structure didn't match
                print("Warning: Could not parse platform entry structure: \(entry)")
            }
        }
        return platforms
    }

    private func extractProducts(from arrayContent: Substring) -> [Package.Product] {
        var products: [Package.Product] = []
        let productEntries = splitBlockIntoEntries(String(arrayContent))

        for entry in productEntries {
            if (entry.contains(".library") || entry.contains(".executable")) && entry.contains("name:") {
                if entry.contains(".library") {
                    if let product = parseLibraryProduct(entry) {
                        products.append(product)
                    }
                } else if entry.contains(".executable") {
                    if let product = parseExecutableProduct(entry) {
                        products.append(product)
                    }
                }
            }
        }
        return products
    }

    private func parseLibraryProduct(_ entry: String) -> Package.Product? {
        let namePattern = /name\s*:\s*"([^"]+)"/
        guard let nameMatch = entry.firstMatch(of: namePattern) else { return nil }
        let name = String(nameMatch.1)

        // Determine product type
        let productType: Package.Product.ProductType
        if entry.contains(".dynamic") {
            productType = .library(.dynamic)
        } else if entry.contains(".static") {
            productType = .library(.static)
        } else {
            productType = .library(.automatic) // Default
        }

        let targets = extractTargetsFromEntry(entry)

        return Package.Product(name: name, type: productType, targets: targets)
    }

    private func parseExecutableProduct(_ entry: String) -> Package.Product? {
        let namePattern = /name\s*:\s*"([^"]+)"/
        guard let nameMatch = entry.firstMatch(of: namePattern) else { return nil }
        let name = String(nameMatch.1)

        let targets = extractTargetsFromEntry(entry)

        return Package.Product(name: name, type: .executable, targets: targets)
    }

    private func extractTargetsFromEntry(_ entry: String) -> [String] {
        var targets: [String] = []

        guard entry.contains("targets:") else { return targets }

        let pattern = try? NSRegularExpression(pattern: "targets\\s*:\\s*\\[([^\\]]*?)\\]", options: [.dotMatchesLineSeparators])
        let nsString = entry as NSString
        let range = NSRange(location: 0, length: nsString.length)

        if let match = pattern?.firstMatch(in: entry, options: [], range: range) {
            let targetsContent = nsString.substring(with: match.range(at: 1))
            let namePattern = try? NSRegularExpression(pattern: "\"([^\"]*)\"", options: [])
            let matches = namePattern?.matches(in: targetsContent, options: [], range: NSRange(location: 0, length: targetsContent.count))

            matches?.forEach { match in
                if match.numberOfRanges > 1 {
                    let targetName = (targetsContent as NSString).substring(with: match.range(at: 1))
                    targets.append(targetName)
                }
            }
        }

        return targets
    }

    private func extractDependencies(from arrayContent: Substring) -> [Package.Dependency] {
        var dependencies: [Package.Dependency] = []
        let dependencyEntries = splitBlockIntoEntries(String(arrayContent))

        for entry in dependencyEntries {
            guard let dependency = parseSingleDependency(entry) else {
                print("Warning: Failed to parse dependency entry: \(entry)")
                continue
            }
            dependencies.append(dependency)
        }
        return dependencies
    }

    private func parseSingleDependency(_ entry: String) -> Package.Dependency? {
        let urlPattern = /url\s*:\s*"([^"]+)"/
        guard let urlMatch = entry.firstMatch(of: urlPattern) else {
            // Note: This currently doesn't handle unlabeled URLs like .package("github.com/...", ...)
            print("Warning: Could not find labeled 'url:' in dependency entry: \(entry)")
            return nil
        }

        let url = String(urlMatch.1)
        let namePattern = /name\s*:\s*"([^"]+)"/
        let name = entry.firstMatch(of: namePattern).map { String($0.1) }

        // Check the entire entry string for keywords and patterns indicating the requirement type.
        // Order matters: check for more specific keywords (.exact, .branch, etc.) before general ones (from:).
        let requirement: Package.Dependency.RequirementType

        if entry.contains(".exact(") {
            requirement = extractExactRequirement(entry)
        } else if entry.contains(".upToNextMajor(from:") {
            requirement = extractUpToNextMajorRequirement(entry)
        } else if entry.contains(".upToNextMinor(from:") {
            requirement = extractUpToNextMinorRequirement(entry)
        } else if entry.contains(".branch(") {
            requirement = extractBranchRequirement(entry)
        } else if entry.contains(".revision(") {
            requirement = extractRevisionRequirement(entry)
        } else if let rangeMatch = entry.firstMatch(of: /from\s*:\s*"([^"]+?)"\s*,\s*to\s*:\s*"([^"]+?)"/) {
            requirement = .range(String(rangeMatch.1), String(rangeMatch.2))
        } else if let rangeMatch = entry.firstMatch(of: /"([^"]+?)"\s*..\s*<"([^"]+?)"/) {
            requirement = .range(String(rangeMatch.1), String(rangeMatch.2))
        } else if let rangeMatch = entry.firstMatch(of: /"([^"]+?)"\s*...\s*"([^"]+?)"/) {
            requirement = .range(String(rangeMatch.1), String(rangeMatch.2))
        } else if let fromMatch = entry.firstMatch(of: /from\s*:\s*"([^"]+?)"/) {
            requirement = .upToNextMajor(String(fromMatch.1))
        } else {
            print("Warning: No requirement specified or recognized in dependency: \(entry). Defaulting to branch 'main'.")
            requirement = .branch("main")
        }

        return Package.Dependency(name: name, url: url, requirement: requirement)
    }

    private func extractExactRequirement(_ entry: String) -> Package.Dependency.RequirementType {
        let versionPattern = /\.exact\(\s*"([^"]+)"\s*\)/
        guard let match = entry.firstMatch(of: versionPattern) else {
            return .exact("unknown")
        }
        return .exact(String(match.1))
    }

    private func extractUpToNextMajorRequirement(_ entry: String) -> Package.Dependency.RequirementType {
        let versionPattern = /\.upToNextMajor\(\s*from:\s*"([^"]+)"\s*\)/
        guard let match = entry.firstMatch(of: versionPattern) else {
            return .upToNextMajor("unknown")
        }
        return .upToNextMajor(String(match.1))
    }

    private func extractUpToNextMinorRequirement(_ entry: String) -> Package.Dependency.RequirementType {
        let versionPattern = /\.upToNextMinor\(\s*from:\s*"([^"]+)"\s*\)/
        guard let match = entry.firstMatch(of: versionPattern) else {
            return .upToNextMinor("unknown")
        }
        return .upToNextMinor(String(match.1))
    }

    private func extractBranchRequirement(_ entry: String) -> Package.Dependency.RequirementType {
        let branchPattern = /\.branch\(\s*"([^"]+)"\s*\)/
        guard let match = entry.firstMatch(of: branchPattern) else {
            return .branch("unknown")
        }
        return .branch(String(match.1))
    }

    private func extractRevisionRequirement(_ entry: String) -> Package.Dependency.RequirementType {
        let revisionPattern = /\.revision\(\s*"([^"]+)"\s*\)/
        guard let match = entry.firstMatch(of: revisionPattern) else {
            return .revision("unknown")
        }
        return .revision(String(match.1))
    }

    private func extractTargets(from arrayContent: Substring) -> [Package.Target] {
        var targets: [Package.Target] = []
        let targetEntries = splitBlockIntoEntries(String(arrayContent))

        for entry in targetEntries {
            guard let target = parseSingleTarget(entry) else {
                print("Warning: Failed to parse target entry: \(entry)")
                continue
            }
            targets.append(target)
        }
        return targets
    }

    private func parseSingleTarget(_ entry: String) -> Package.Target? {
        let targetType: Package.Target.TargetType

        if entry.contains(".testTarget") {
            targetType = .test
        } else if entry.contains(".systemLibrary") {
            targetType = .system
        } else if entry.contains(".binaryTarget") {
            targetType = .binary
        } else if entry.contains(".plugin") {
            targetType = .plugin
        } else if entry.contains(".executableTarget") {
            targetType = .regular
        } else if entry.contains(".target") {
            targetType = .regular
        } else {
            return nil
        }

        let namePattern = try? NSRegularExpression(pattern: "name\\s*:\\s*\"([^\"]+)\"", options: [.dotMatchesLineSeparators])
        let nsString = entry as NSString
        let range = NSRange(location: 0, length: nsString.length)

        guard let nameMatch = namePattern?.firstMatch(in: entry, options: [], range: range) else {
            return nil
        }

        let name = nsString.substring(with: nameMatch.range(at: 1))

        // Extract path if present
        let pathPattern = try? NSRegularExpression(pattern: "path\\s*:\\s*\"([^\"]+)\"", options: [.dotMatchesLineSeparators])
        let pathMatch = pathPattern?.firstMatch(in: entry, options: [], range: range)
        let path = pathMatch.map { nsString.substring(with: $0.range(at: 1)) }

        // Extract other parameters
        let dependencies = extractTargetDependencies(from: Substring(entry))
        let exclude = extractStringArrayParameter(named: "exclude", from: Substring(entry))
        let sources = extractStringArrayParameter(named: "sources", from: Substring(entry))
        let resources = extractResources(from: Substring(entry))

        return Package.Target(
            name: name,
            type: targetType,
            dependencies: dependencies,
            path: path,
            exclude: exclude,
            sources: sources,
            resources: resources
        )
    }

    private func extractTargetDependencies(from targetParamsContent: Substring) -> [Package.TargetDependency] {
        var dependencies: [Package.TargetDependency] = []

        guard let depLabelRange = targetParamsContent.range(of: "dependencies:") else {
            return []
        }

        var searchSubstring = targetParamsContent[depLabelRange.upperBound...].lstrip() // Remove leading whitespace
        guard searchSubstring.starts(with: "[") else {
            print("Warning: Found 'dependencies:' label but no opening bracket '[' follows.")
            return []
        }

        let arrayContentStartIndex = searchSubstring.index(after: searchSubstring.startIndex)
        guard let arrayContentEndIndex = findMatchingBracket(in: searchSubstring[arrayContentStartIndex...]) else {
            print("Warning: Could not find matching ']' for target dependencies array.")
            return []
        }

        let depArrayContent = searchSubstring[arrayContentStartIndex..<arrayContentEndIndex]
        let trimmedContent = String(depArrayContent).trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedContent.isEmpty {
            return []
        }

        let dependencyEntries = splitBlockIntoEntries(trimmedContent)

        for depEntry in dependencyEntries {
            if depEntry.contains(".product") {
                if let dep = parseProductDependency(depEntry) { dependencies.append(dep) }
                else { print("Warning: Failed to parse product dependency entry: \(depEntry)") }
            } else if depEntry.contains(".target") {
                if let dep = parseTargetDependency(depEntry) { dependencies.append(dep) }
                else { print("Warning: Failed to parse target dependency entry: \(depEntry)") }
            } else if let nameMatch = depEntry.firstMatch(of: /"([^"]+)"/) {
                dependencies.append(.byName(name: String(nameMatch.1)))
            } else if let nameMatch = depEntry.firstMatch(of: /\.byName\(\s*name:\s*"([^"]+)"\s*\)/) {
                dependencies.append(.byName(name: String(nameMatch.1)))
            } else {
                print("Warning: Could not parse target dependency entry: \(depEntry)")
            }
        }

        return dependencies
    }

    private func parseProductDependency(_ entry: String) -> Package.TargetDependency? {
        let productPattern = /\.product\(\s*name:\s*"([^"]+)"(?:,\s*package:\s*"([^"]+)")?\s*\)/
        guard let match = entry.firstMatch(of: productPattern) else {
            return nil
        }
        let name = String(match.1)
        let package = match.2.map { String($0) }
        return .product(name: name, package: package)
    }

    private func parseTargetDependency(_ entry: String) -> Package.TargetDependency? {
        let targetPattern = /\.target\(\s*name:\s*"([^"]+)"\s*\)/
        guard let match = entry.firstMatch(of: targetPattern) else { return nil }
        let name = String(match.1)
        return .target(name: name)
    }

    private func extractStringArrayParameter(named name: String, from content: Substring) -> [String] {
        var patterns: [String] = []

        let arrayRegex = Regex {
            name
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            "["
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            "]"
        }
        .dotMatchesNewlines(true)

        guard let arrayMatch = content.firstMatch(of: arrayRegex) else { return [] }

        let arrayContent = arrayMatch.1
        let stringPattern = /"([^"]+)"/
        let matches = arrayContent.matches(of: stringPattern)

        for match in matches {
            patterns.append(String(match.1))
        }
        return patterns
    }

    private func extractResources(from targetParamsContent: Substring) -> [Package.Resource] {
        var resources: [Package.Resource] = []

        guard let resLabelRange = targetParamsContent.range(of: "resources:") else {
            return []
        }

        var searchSubstring = targetParamsContent[resLabelRange.upperBound...].lstrip()
        guard searchSubstring.starts(with: "[") else {
            print("Warning: Found 'resources:' label but no opening bracket '[' follows.")
            return []
        }

        let arrayContentStartIndex = searchSubstring.index(after: searchSubstring.startIndex)

        guard let arrayContentEndIndex = findMatchingBracket(in: searchSubstring[arrayContentStartIndex...]) else {
            print("Warning: Could not find matching ']' for target resources array.")
            return []
        }

        let resourceArrayContent = searchSubstring[arrayContentStartIndex..<arrayContentEndIndex]
        let trimmedContent = String(resourceArrayContent).trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedContent.isEmpty {
            return []
        }

        let resourceEntries = splitBlockIntoEntries(trimmedContent)

        for resEntry in resourceEntries {
            let rule: Package.Resource.Rule = resEntry.contains(".process") ? .process : .copy
            let pathPattern = /\.(?:process|copy)\(\s*"([^"]+)"\s*\)/

            if let pathMatch = resEntry.firstMatch(of: pathPattern) {
                let path = String(pathMatch.1)
                resources.append(Package.Resource(path: path, rule: rule))
            } else {
                print("Warning: Could not parse resource entry format: \(resEntry)")
            }
        }

        return resources
    }

    private func extractSwiftLanguageVersions(from arrayContent: Substring) -> [String] {
        var versions: [String] = []
        let versionEntries = splitBlockIntoEntries(String(arrayContent))

        for entry in versionEntries {
            if let match = entry.firstMatch(of: /\.v([a-zA-Z0-9_]+)/) { //.v5, .v5_2
                versions.append(String(match.1).replacingOccurrences(of: "_", with: "."))
            } else if let match = entry.firstMatch(of: /\.version\(\s*"([^"]+)"\s*\)/) { // .version("5.3")
                versions.append(String(match.1))
            }
        }
        return versions
    }

    private func findNextParameterOrComma(in substring: Substring) -> Substring.Index? {
        let knownParameters = ["name:", "platforms:", "products:", "dependencies:", "targets:",
                               "swiftLanguageVersions:", "cLanguageStandard:", "cxxLanguageStandard:"]

        if let commaIndex = substring.firstIndex(of: ",") {
            return commaIndex
        }

        for param in knownParameters {
            if let paramIndex = substring.range(of: param)?.lowerBound {
                return paramIndex
            }
        }

        return nil
    }

    private func splitBlockIntoEntries(_ block: String) -> [String] {
        var entries: [String] = []
        var currentDepth = 0
        var currentEntry = ""
        var inString = false
        var inSingleLineComment = false
        var inMultiLineComment = false
        var i = block.startIndex

        while i < block.endIndex {
            let char = block[i]

            if !inString {
                if !inSingleLineComment && !inMultiLineComment && char == "/" && i < block.index(before: block.endIndex) {
                    let nextIndex = block.index(after: i)
                    let nextChar = block[nextIndex]

                    if nextChar == "/" {
                        inSingleLineComment = true
                        currentEntry.append(char)
                        currentEntry.append(nextChar)
                        i = block.index(after: nextIndex)
                        continue
                    } else if nextChar == "*" {
                        inMultiLineComment = true
                        currentEntry.append(char)
                        currentEntry.append(nextChar)
                        i = block.index(after: nextIndex)
                        continue
                    }
                }

                if inSingleLineComment && char == "\n" {
                    inSingleLineComment = false
                    currentEntry.append(char)
                    i = block.index(after: i)
                    continue
                }

                if inMultiLineComment && char == "*" && i < block.index(before: block.endIndex) {
                    let nextIndex = block.index(after: i)
                    if block[nextIndex] == "/" {
                        inMultiLineComment = false
                        currentEntry.append(char)
                        currentEntry.append("/")
                        i = block.index(after: nextIndex)
                        continue
                    }
                }
            }

            if !inSingleLineComment && !inMultiLineComment && char == "\"" && (i == block.startIndex || block[block.index(before: i)] != "\\") {
                inString.toggle()
            }

            if !inString && !inSingleLineComment && !inMultiLineComment {
                if char == "(" || char == "[" || char == "{" {
                    currentDepth += 1
                } else if char == ")" || char == "]" || char == "}" {
                    currentDepth = max(0, currentDepth - 1)
                }

                if char == "," && currentDepth == 0 {
                    let trimmed = currentEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        entries.append(trimmed)
                    }
                    currentEntry = ""
                    i = block.index(after: i)
                    continue
                }
            }

            currentEntry.append(char)
            i = block.index(after: i)
        }

        let trimmed = currentEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            entries.append(trimmed)
        }

        return entries
    }
}

extension Substring {
    func lstrip() -> Substring {
        guard let firstNonWhitespace = self.firstIndex(where: { !$0.isWhitespace }) else {
            return self[self.endIndex...]
        }
        return self[firstNonWhitespace...]
    }
}
