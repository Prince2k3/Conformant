public struct Box<Element: Codable, Failure: Error> {
    let value: Element
    let store: Dictionary<String, [CacheEntry]>
    let transform: (Request) throws -> Response
    let optionalPair: (first: Left, second: Right)?
}

func constrained<T>(_ input: T) -> T where T: Comparable & Hashable {
    input
}

struct Qualified {
    let a: Swift.Int
    let b: MyModule.Deep.Nested.Type1
    let c: any Sendable
    let d: some Equatable = 1
    let e: [Int: [String: UserProfile]]
    let f: UnsafePointer<CChar>?
}
