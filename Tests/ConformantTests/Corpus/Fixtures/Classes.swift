import Foundation

public final class UserService: BaseService, Sendable, CustomStringConvertible {
    private let repository: UserRepository
    internal var cache: [String: CachedUser] = [:]
    public var description: String { "UserService" }

    public init(repository: UserRepository) {
        self.repository = repository
    }

    open func fetch(id: UserID) async throws -> User {
        try await repository.load(id)
    }

    private static func makeDefault() -> UserService {
        UserService(repository: InMemoryUserRepository())
    }
}

class Minimal {}
