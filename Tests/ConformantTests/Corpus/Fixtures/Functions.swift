import Foundation

public func topLevel(a: Int, b named: String = "x", _ c: Data) -> Result<User, NetworkError> {
    .failure(.timeout)
}

func asyncThrowing() async throws -> Void {}

func rethrowing(_ body: () throws -> Void) rethrows {}

@discardableResult
@inlinable
func annotated<T: Sendable>(_ value: T) -> T { value }

infix operator |>: AdditionPrecedence
