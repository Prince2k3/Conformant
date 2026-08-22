struct Container {
    subscript(index: Int) -> Element {
        get { fatalError() }
    }

    static func == (lhs: Container, rhs: Container) -> Bool { true }

    init?(failable: RawInput) { nil }
}

final class Resource {
    deinit {
        cleanup()
    }
}

typealias Handler = (Result<Data, NetworkError>) -> Void
typealias Pair<T> = (T, T)
