import Foundation

/// Represents a Swift package with its properties
public struct Package {
    public let name: String
    public let platforms: [Platform]
    public let products: [Product]
    public let dependencies: [Dependency]
    public let targets: [Target]
    public let swiftLanguageVersions: [String]
    public let cLanguageStandard: String?
    public let cxxLanguageStandard: String?
}

extension Package {
    /// Represents a platform requirement
    public struct Platform {
        public let name: String
        public let version: String

        public init(name: String, version: String) {
            self.name = name
            self.version = version
        }
    }

    /// Represents a product defined in the package
    public struct Product {
        public enum ProductType {
            case library(LibraryType)
            case executable

            public enum LibraryType {
                case dynamic
                case `static`
                case automatic
            }
        }

        public let name: String
        public let type: ProductType
        public let targets: [String]

        public init(name: String, type: ProductType, targets: [String]) {
            self.name = name
            self.type = type
            self.targets = targets
        }
    }

    /// Represents a package dependency
    public struct Dependency {
        public enum RequirementType {
            case exact(String)
            case upToNextMajor(String)
            case upToNextMinor(String)
            case branch(String)
            case revision(String)
            case range(String, String)
        }

        public let name: String?
        public let url: String
        public let requirement: RequirementType

        public init(name: String?, url: String, requirement: RequirementType) {
            self.name = name
            self.url = url
            self.requirement = requirement
        }
    }

    /// Represents a target in the package
    public struct Target {
        public enum TargetType {
            case regular
            case test
            case system
            case binary
            case plugin
        }

        public let name: String
        public let type: TargetType
        public let dependencies: [TargetDependency]
        public let path: String?
        public let exclude: [String]
        public let sources: [String]
        public let resources: [Resource]

        public init(name: String, type: TargetType, dependencies: [TargetDependency], path: String?, exclude: [String], sources: [String], resources: [Resource]) {
            self.name = name
            self.type = type
            self.dependencies = dependencies
            self.path = path
            self.exclude = exclude
            self.sources = sources
            self.resources = resources
        }
    }

    /// Represents a target dependency
    public enum TargetDependency {
        case target(name: String)
        case product(name: String, package: String?)
        case byName(name: String)
    }

    /// Represents a resource
    public struct Resource {
        public enum Rule {
            case process
            case copy
        }

        public let path: String
        public let rule: Rule

        public init(path: String, rule: Rule) {
            self.path = path
            self.rule = rule
        }
    }
}
