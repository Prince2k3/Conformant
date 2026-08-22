precedencegroup PipelinePrecedence {
    associativity: left
    assignment: false
    higherThan: AdditionPrecedence
    lowerThan: MultiplicationPrecedence
}

infix operator |>: PipelinePrecedence
prefix operator ~~
postfix operator ^^

@freestanding(expression)
public macro stringify<Value>(_ value: Value) -> (Value, String) =
    #externalMacro(module: "ConformantMacros", type: "StringifyMacro")

@attached(member, names: named(identifier))
macro Identified() = #externalMacro(module: "ConformantMacros", type: "IdentifiedMacro")

public typealias Handler = (Request) -> Response
typealias Pair<Value> = (Value, Value)

public struct Matrix {
    private var storage: [Double]
    let columns: Int

    public subscript(row: Int, column: Int) -> Double {
        get { storage[row * columns + column] }
        set { storage[row * columns + column] = newValue }
    }

    subscript(flat index: Int) -> Double {
        storage[index]
    }
}

public protocol Repository {
    associatedtype Entity: Identifiable
    associatedtype Failure: Error = NetworkError

    subscript(id: Entity.ID) -> Entity? { get }
}

final class Session {
    private let socket: Socket

    init(socket: Socket) {
        self.socket = socket
    }

    deinit {
        socket.close()
    }
}
