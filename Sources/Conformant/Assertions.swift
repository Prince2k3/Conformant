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

    /// Assert that at least one element matches the given predicate
    public func assertAny(predicate: (Element) -> Bool) -> Bool {
        return self.contains(where: predicate)
    }

    /// Assert that no elements match the given predicate
    public func assertNone(predicate: (Element) -> Bool) -> Bool {
        return !self.contains(where: predicate)
    }
}
