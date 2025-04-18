import Foundation

/// Base protocol for all Swift declarations
public protocol SwiftDeclaration {
    var name: String { get }
    var modifiers: [SwiftModifier] { get }
    var annotations: [SwiftAnnotation] { get }
    var dependencies: [SwiftDependency] { get }
    var filePath: String { get }
    var location: SourceLocation { get }

    func hasAnnotation(named: String) -> Bool
    func hasModifier(_ modifier: SwiftModifier) -> Bool
    func resideInPackage(_ packagePattern: String) -> Bool
}

/// Default implementation for SwiftDeclaration methods
extension SwiftDeclaration {
    public func hasAnnotation(named name: String) -> Bool {
        annotations.contains { $0.name == name }
    }

    public func hasModifier(_ modifier: SwiftModifier) -> Bool {
        modifiers.contains(modifier)
    }

    public func resideInPackage(_ packagePattern: String) -> Bool {
        let regexPattern = packagePattern.replacingOccurrences(of: "..", with: ".*")

        do {
            let regex = try Regex(regexPattern)
            return filePath.contains(regex)
        } catch {
            print("Invalid regex pattern: \(regexPattern) - \(error)")
            return false
        }
    }
}
