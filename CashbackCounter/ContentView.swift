import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView(selection: $selectedTab) {
            CardStackHomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "creditcard.fill" : "creditcard")
                    Text("卡包")
                }
                .tag(0)

            BestCardView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "star.fill" : "star")
                    Text("推荐")
                }
                .tag(1)

            ReminderCenterView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "bell.fill" : "bell")
                    Text("提醒")
                }
                .tag(2)

            LibraryView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "square.grid.2x2.fill" : "square.grid.2x2")
                    Text("更多")
                }
                .tag(3)
        }
        .tint(.blue)
        .task {
            do {
                try Point.syncDefaultPoints(in: context)
            } catch {
                print("Failed to sync point templates: \(error)")
            }
        }
    }
}
