import Foundation

/// Represents a layer in the architecture
public struct Layer {
    let name: String
    let resideIn: (any SwiftDeclaration) -> Bool

    // A set of module names that are considered part of this layer
    // Used for import-based dependency checking
    private let modulesInLayer: Set<String>

    /// Initialize a Layer with a name and a regex pattern to match file paths
    public init(name: String, identifierPattern: String) {
        self.name = name
        self.modulesInLayer = [] // No specific modules defined
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

            // Alternative/More Robust (might be needed if paths are tricky):
            // Use URL path components
            // let declURL = URL(fileURLWithPath: declaration.filePath)
            // return declURL.pathComponents.contains(targetDir)
        }
    }

    /// Initialize a Layer with a name and a module name
    public init(name: String, module: String) {
        self.name = name
        self.modulesInLayer = [module]
        self.resideIn = { declaration in
            // Use URL path components for more robust checking
            let components = URL(fileURLWithPath: declaration.filePath).pathComponents
            let result = components.contains(module) // Check if module name exists as a path component
             print("DEBUG resideIn(Module): Layer='\(name)' Module='\(module)' DeclPath='\(declaration.filePath)' Components='\(components)' Contains=\(result)")
            return result
        }
    }

    /// Initialize a Layer with a name and multiple module names
    public init(name: String, modules: [String]) {
         self.name = name
         self.modulesInLayer = Set(modules)
         self.resideIn = { declaration in
             let components = URL(fileURLWithPath: declaration.filePath).pathComponents
             // Check if any specified module name exists as a path component
             let result = modules.contains { module in
                 components.contains(module)
             }
             print("DEBUG resideIn(Modules): Layer='\(name)' Modules='\(modules)' DeclPath='\(declaration.filePath)' Components='\(components)' Contains=\(result)")
             return result
         }
     }

    /// Initialize a Layer with a name and a custom predicate
    public init(name: String, predicate: @escaping (any SwiftDeclaration) -> Bool) {
        self.name = name
        self.modulesInLayer = [] // No specific modules defined
        self.resideIn = predicate
    }

    /// Initialize a Layer with a name, modules, and a custom predicate
    public init(name: String, modules: [String], predicate: @escaping (any SwiftDeclaration) -> Bool) {
        self.name = name
        self.modulesInLayer = Set(modules)
        self.resideIn = predicate
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
