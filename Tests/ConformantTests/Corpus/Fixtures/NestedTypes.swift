public struct Outer {
    public struct Inner {
        let repository: UserRepository
    }

    public enum Kind {
        case primary
        case secondary
    }

    final class DeeplyNested {
        struct EvenDeeper {
            let client: NetworkClient
        }
    }

    let inner: Inner
}
