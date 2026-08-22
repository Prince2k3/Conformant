public actor BankAccount {
    private var balance: Decimal = 0
    private let ledger: TransactionLedger

    public init(ledger: TransactionLedger) {
        self.ledger = ledger
    }

    public func deposit(_ amount: Decimal) async throws -> Receipt {
        balance += amount
        return try await ledger.record(amount)
    }

    nonisolated public var identifier: AccountID { AccountID() }
}

@globalActor
actor BackgroundActor {
    static let shared = BackgroundActor()
}
