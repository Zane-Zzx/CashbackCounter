import SwiftUI
import SwiftData

struct LibraryView: View {
    @State private var rootSheet: SheetType? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("管理") {
                    NavigationLink(destination: CardTemplateListView(rootSheet: $rootSheet)) {
                        Label("卡片模板", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(destination: PointSystemView()) {
                        Label("积分管理", systemImage: "star.circle")
                    }
                }
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("规则库")
        }
    }
}
