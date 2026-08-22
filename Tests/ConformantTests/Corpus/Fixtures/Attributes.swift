@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class Modern: NSObject, @unchecked Sendable {
    @objc dynamic var observed: Int = 0
}

@propertyWrapper
struct Clamped {
    var wrappedValue: Int
}

@resultBuilder
enum ViewBuilder2 {
    static func buildBlock(_ parts: Component...) -> Component { parts[0] }
}

@main
struct App {
    static func main() {}
}

@_silgen_name("c_entry")
func entry() {}
