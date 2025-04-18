import Foundation

/// Represents a Swift parameter declaration
public class SwiftParameterDeclaration {
    public let name: String
    public let type: String
    public let defaultValue: String?

    init(name: String, type: String, defaultValue: String? = nil) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
    }
}
