final class Controller {
    func run() {
        let repository = UserRepository()
        DatabaseClient.shared.connect()
        _ = Logger(label: "controller")

        guard let parsed = Parser.parse("x") as? ParsedValue else { return }
        print(parsed)

        let handler: (AnalyticsEvent) -> Void = { event in
            Tracker.record(event)
        }
        handler(.launched)
    }
}
