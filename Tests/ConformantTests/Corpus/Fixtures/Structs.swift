public struct Money: Codable, Hashable {
    public let amount: Decimal
    public let currency: CurrencyCode
    public var formatted: String { "\(amount)" }

    public func converted(to target: CurrencyCode, using rate: ExchangeRate) -> Money {
        Money(amount: amount, currency: target)
    }
}

struct Empty {}
