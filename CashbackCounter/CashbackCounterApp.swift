import SwiftUI
import SwiftData

@main
struct CashbackCounterApp: App {
    @AppStorage("userTheme") private var userTheme: Int = 0
    @AppStorage("userLanguage") private var userLanguage: String = "system"

    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            .preferredColorScheme(userTheme == 1 ? .light : (userTheme == 2 ? .dark : nil))
            .environment(\.locale, userLanguage == "system" ? .current : Locale(identifier: userLanguage))
        }
        .modelContainer(for: [Transaction.self, CreditCard.self, CardTemplate.self, Income.self, Point.self, PointAdjustment.self])
    }
}
