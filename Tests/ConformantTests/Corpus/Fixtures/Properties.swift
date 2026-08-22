import SwiftUI

let topLevelConstant: Configuration = Configuration()
var topLevelVariable = 42

struct WithProperties {
    @Environment(\.locale) private var locale
    @Published var items: [Item] = []
    @State private var isPresented = false

    let multiA: Int, multiB: String
    lazy var expensive: ExpensiveResource = ExpensiveResource()
    weak var delegate: SomeDelegate?
    unowned let owner: Owner

    var computed: Int { 1 }
    var withAccessors: Int {
        get { 1 }
        set { }
    }
}
