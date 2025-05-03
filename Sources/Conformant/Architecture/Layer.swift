//
//  Layer.swift
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

/// Represents a layer in the architecture
public struct Layer {
    let name: String
    let resideIn: (any SwiftDeclaration) -> Bool

    // A set of module names that are considered part of this layer
    // Used for import-based dependency checking
    private let modulesInLayer: Set<String>

    @MainActor private static var packageCache: [String: PackageFile] = [:]

    /// Initialize a Layer with a name and a regex pattern to match file paths
    public init(name: String, identifierPattern: String) {
        self.name = name
        self.modulesInLayer = []
        self.resideIn = { declaration in
            let filePath = declaration.filePath
            let regexPattern = identifierPattern.replacingOccurrences(of: "..", with: ".*")
            do {
                let regex = try Regex(regexPattern)
                return filePath.contains(regex)
            } catch {
                print("Invalid regex pattern in Layer definition: \(regexPattern) - \(error)")
                return false
            }
        }
    }

    /// Initialize a Layer with a name and a directory path
    public init(name: String, directory: String) {
        self.name = name
        self.modulesInLayer = []
        self.resideIn = { declaration in
            let targetDir = directory
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            let declPath = declaration.filePath
                .replacingOccurrences(of: "\\", with: "/")

            guard !targetDir.isEmpty else { return false }

            let pattern1 = "/\(targetDir)/"

            return declPath.contains(pattern1)
        }
    }

    /// Initialize a Layer with a name and a Swift package target
    @MainActor
    public init(name: String, packageTarget: String, fileManager: FileManager = .default) {
        self.name = name
        self.modulesInLayer = [packageTarget]
        self.resideIn = { declaration in
            return Layer.declarationBelongsToPackageTarget(declaration, targetName: packageTarget, fileManager: fileManager)
        }
    }

    /// Initialize a Layer with a name and multiple Swift package targets
    @MainActor
    public init(name: String, packageTargets: [String], fileManager: FileManager = .default) {
        self.name = name
        self.modulesInLayer = Set(packageTargets)
        self.resideIn = { declaration in
            // Check if the declaration belongs to any of the specified targets
            for target in packageTargets {
                if Layer.declarationBelongsToPackageTarget(declaration, targetName: target, fileManager: fileManager) {
                    return true
                }
            }
            return false
        }
    }

    /// Initialize a Layer with a name and a custom predicate
    public init(name: String, predicate: @escaping (any SwiftDeclaration) -> Bool) {
        self.name = name
        self.modulesInLayer = []
        self.resideIn = predicate
    }

    /// Initialize a Layer with a name, modules, and a custom predicate
    public init(name: String, modules: [String], predicate: @escaping (any SwiftDeclaration) -> Bool) {
        self.name = name
        self.modulesInLayer = Set(modules)
        self.resideIn = predicate
    }

    /// Helper method to determine if a declaration belongs to a specific package target
    @MainActor private static func declarationBelongsToPackageTarget(_ declaration: any SwiftDeclaration, targetName: String, fileManager: FileManager = .default) -> Bool {
        let packageSwiftPath = findNearestPackageSwift(from: declaration.filePath, fileManager: fileManager)
        guard let packageSwiftPath = packageSwiftPath else {
            return false
        }

        let package: PackageFile

        if let cachedPackage = packageCache[packageSwiftPath] {
            package = cachedPackage
        } else {
            do {
                guard let data = fileManager.contents(atPath: packageSwiftPath),
                      let content = String(data: data, encoding: .utf8) else {
                    return false
                }
                let parser = PackageSwiftParser(content: content)
                let parsedPackage = try parser.parse()
                packageCache[packageSwiftPath] = parsedPackage
                package = parsedPackage
            } catch {
                print("Error parsing Package.swift at \(packageSwiftPath): \(error)")
                return false
            }
        }

        guard let target = package.targets.first(where: { $0.name == targetName }) else {
            return false
        }

        let packageDirPath = (packageSwiftPath as NSString).deletingLastPathComponent
        let normalizedDeclPath = declaration.filePath.replacingOccurrences(of: "\\", with: "/")

        // Try multiple path patterns to account for different project structures

        if let targetPath = target.path {
            let targetFullPath = (packageDirPath as NSString).appendingPathComponent(targetPath)
                .replacingOccurrences(of: "\\", with: "/")

            if normalizedDeclPath.hasPrefix(targetFullPath) ||
               normalizedDeclPath.contains("/\(targetPath)/") {
                return true
            }
        }

        let defaultTargetPath = (packageDirPath as NSString)
            .appendingPathComponent("Sources/\(targetName)")
            .replacingOccurrences(of: "\\", with: "/")

        if normalizedDeclPath.hasPrefix(defaultTargetPath) ||
           normalizedDeclPath.contains("/Sources/\(targetName)/") {
            return true
        }

        if normalizedDeclPath.contains("/\(targetName)/") {
            return true
        }

        for excludePath in target.exclude {
            let fullExcludePath = target.path != nil
            ? (packageDirPath as NSString).appendingPathComponent("\(target.path!)/\(excludePath)")
            : (packageDirPath as NSString).appendingPathComponent("Sources/\(targetName)/\(excludePath)")

            if normalizedDeclPath.hasPrefix(fullExcludePath) {
                return false
            }
        }

        if !target.sources.isEmpty {
            let inSpecifiedSources = target.sources.contains { sourcePath in
                let fullSourcePath = target.path != nil
                ? (packageDirPath as NSString).appendingPathComponent("\(target.path!)/\(sourcePath)")
                : (packageDirPath as NSString).appendingPathComponent("Sources/\(targetName)/\(sourcePath)")

                return normalizedDeclPath.hasPrefix(fullSourcePath)
            }

            return inSpecifiedSources
        }

        return false
    }

    /// Find the nearest Package.swift file by traversing up the directory tree
    private static func findNearestPackageSwift(from filePath: String, fileManager: FileManager = .default) -> String? {
        var currentDir = (filePath as NSString).deletingLastPathComponent
        var checkedDirs = Set<String>()

        while !currentDir.isEmpty && currentDir != "/" && !checkedDirs.contains(currentDir) {
            checkedDirs.insert(currentDir)
            let packagePath = (currentDir as NSString).appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packagePath) {
                return packagePath
            }
            currentDir = (currentDir as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// Check if a dependency points to this layer based on module imports
    public func containsDependency(_ dependency: SwiftDependency) -> Bool {
        guard dependency.kind == .import else { return false }
        return modulesInLayer.contains(dependency.name)
    }

    /// Create a rule specifying this layer should depend on another layer
    public func dependsOn(_ layer: Layer) -> ArchitectureRule {
        return DependsOnRule(source: self, target: layer)
    }

    /// Create a rule specifying this layer should not depend on any other layer
    public func dependsOnNothing() -> ArchitectureRule {
        return DependsOnNothingRule(source: self)
    }

    /// Create a rule specifying this layer can only depend on specified layers
    public func onlyDependsOn(_ layers: Layer...) -> ArchitectureRule {
        return OnlyDependsOnRule(source: self, targetLayers: layers)
    }

    /// Create a rule specifying this layer should not depend on specified layers
    public func mustNotDependOn(_ layers: Layer...) -> ArchitectureRule {
        return MustNotDependOnRule(source: self, forbiddenLayers: layers)
    }
}
