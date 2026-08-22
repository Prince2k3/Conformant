public protocol Repository: AnyObject, Sendable {
    associatedtype Item
    associatedtype Failure: Error

    var count: Int { get }
    var name: String { get set }

    func load(_ id: Identifier) async throws -> Item
    func save(_ item: Item) throws
}

protocol Marker {}
