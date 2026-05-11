import SwiftUI
import SwiftData

struct LibraryView: View {
    @State private var rootSheet: SheetType? = nil

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "管理")) {
                    NavigationLink(destination: CardTemplateListView(rootSheet: $rootSheet)) {
                        Label(String(localized: "卡片模板"), systemImage: "square.grid.2x2")
                    }
                    NavigationLink(destination: PointSystemView()) {
                        Label(String(localized: "积分管理"), systemImage: "star.circle")
                    }
                }
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label(String(localized: "设置"), systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle(String(localized: "规则库"))
        }
    }
}
