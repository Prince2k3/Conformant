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
