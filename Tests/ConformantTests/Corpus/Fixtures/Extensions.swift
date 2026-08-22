import Foundation

extension String: Identifiable {
    public var id: String { self }
}

extension Array where Element: Repository {
    func loadAll() async throws -> [Element.Item] { [] }
}

private extension Money {
    var isZero: Bool { amount == 0 }
}
