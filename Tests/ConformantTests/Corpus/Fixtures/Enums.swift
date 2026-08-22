public enum HTTPStatus: Int, Codable {
    case ok = 200
    case notFound = 404
}

enum LoadState {
    case idle
    case loading(progress: Double)
    case loaded(User, ETag)
    case failed(NetworkError)

    var isTerminal: Bool {
        switch self {
        case .loaded, .failed: return true
        default: return false
        }
    }
}

indirect enum Expression {
    case literal(Int)
    case add(Expression, Expression)
}
