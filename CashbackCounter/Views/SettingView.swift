//
//  SettingsView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/29/25.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Helper Models
// 1. 新增：用于封装分享数据的结构体，遵循 Identifiable 协议
// 这解决了 .sheet(isPresented:) 导致的时序问题
struct ShareData: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct SettingsView: View {
    // MARK: - Properties
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    @AppStorage("userTheme") private var userTheme: Int = 0
    @AppStorage("userLanguage") private var userLanguage: String = "system"
    @AppStorage("mainCurrencyCode") private var mainCurrencyCode: String = "CNY"
    
    @Environment(\.modelContext) var context
    @State private var showConfirmClear: Bool = false
    
    // 获取数据库数据
    @Query var cards: [CreditCard]
    @Query var points: [Point]
    
    // MARK: - Export State
    // 2. 修改：使用 item 形式的状态来控制 Sheet
    @State private var shareData: ShareData?
    // 3. 新增：控制导出过程中的 Loading 状态
    @State private var isExporting = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                // Header Section
                Section {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                                .offset(x: -5, y: 0)
                            
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                                .padding(4)
                                .background(Color(uiColor: .systemGroupedBackground).clipShape(Circle()))
                                .offset(x: 18, y: 12)
                        }
                        .padding(.bottom, 4)
                        
                        Text(String(localized: "卡择"))
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)
                
                // Appearance Section
                Section(header: Text(String(localized: "外观与语言"))) {
                    Picker(selection: $userTheme, label: Label(String(localized: "主题模式"), systemImage: "paintpalette")) {
                        Text(String(localized: "跟随系统")).tag(0)
                        Text(String(localized: "浅色模式")).tag(1)
                        Text(String(localized: "深色模式")).tag(2)
                    }

                    Picker(selection: $userLanguage, label: Label(String(localized: "语言设置"), systemImage: "globe")) {
                        Text(String(localized: "跟随系统")).tag("system")
                        Text("简体中文").tag("zh-Hans")
                        Text("繁體中文").tag("zh-Hant")
                        Text("English").tag("en")
                    }
                }

                // General Section
                Section(header: Text(String(localized: "常规"))) {
                    Picker(selection: $mainCurrencyCode, label: Label(String(localized: "主货币"), systemImage: "banknote")) {
                        Text("人民币 (CNY)").tag("CNY")
                        Text("美元 (USD)").tag("USD")
                        Text("港币 (HKD)").tag("HKD")
                        Text("日元 (JPY)").tag("JPY")
                    }

                    NavigationLink(destination: NotificationSettingsView()) {
                        Label(String(localized: "通知提醒"), systemImage: "bell")
                    }
                }

                // Data Management Section
                Section(header: Text(String(localized: "数据管理"))) {
                    Button {
                        startExportProcess()
                    } label: {
                        HStack {
                            Label(String(localized: "导出卡片与积分数据"), systemImage: "square.and.arrow.up")
                            Spacer()

                            if isExporting {
                                ProgressView()
                                    .padding(.leading, 5)
                            }
                        }
                    }
                    .disabled(isExporting)

                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label(String(localized: "隐私政策"), systemImage: "hand.raised")
                    }
                }

                // About Section
                Section(header: Text(String(localized: "关于 卡择"))) {
                    HStack {
                        Label(String(localized: "版本"), systemImage: "info.circle")
                        Spacer()
                        Text("v\(appVersion)")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: DeveloperView()) {
                        Label(String(localized: "开发者/贡献者"), systemImage: "person.crop.circle")
                    }
                }

                Section(header: Text(String(localized: "更新说明"))) {
                    NavigationLink(destination: UpdateNotesView(appVersion: appVersion)) {
                        Label(String(localized: "更新版本注意事项"), systemImage: "exclamationmark.triangle")
                    }
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        showConfirmClear = true
                    } label: {
                        Label(String(localized: "重置所有数据 (慎用)"), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .confirmationDialog(
                        String(localized: "确定要清除所有数据吗？"),
                        isPresented: $showConfirmClear,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "清除"), role: .destructive) {
                            clearAllData()
                        }
                        Button(String(localized: "取消"), role: .cancel) {}
                    }
                }
            }
            .navigationTitle(String(localized: "设置"))
            .listStyle(.insetGrouped)
            // 4. 关键修复：使用 item: $shareData 绑定
            // 只有当 shareData 有值时，才会初始化并显示 ActivityViewController
            .sheet(item: $shareData) { data in
                ActivityViewController(activityItems: data.items)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Logic Methods
    
    /// 开始异步导出流程
    private func startExportProcess() {
        // 1. 开启 Loading 状态
        isExporting = true
        
        Task {
            // 2. 稍微延迟一点点 (0.2秒)，让 UI 有机会刷新出 ProgressView
            // 否则在主线程做繁重工作会直接卡住 UI，连转圈都看不到
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // 3. 执行导出数据生成 (耗时操作)
            let items = generateExportItems()
            
            // 4. 完成后更新 UI 状态
            // Task 在 SwiftUI View 中默认运行在 MainActor，所以可以直接更新 State
            isExporting = false
            
            if !items.isEmpty {
                // 赋值给 shareData，自动触发 .sheet(item: ...)
                self.shareData = ShareData(items: items)
            }
        }
    }
    
    /// 生成导出文件 (CSV)
    private func generateExportItems() -> [Any] {
        var items: [Any] = []

        if let cardCSV = cards.exportCSVFile() {
            items.append(cardCSV)
        }

        if !points.isEmpty, let pointsCSV = exportPointsCSV() {
            items.append(pointsCSV)
        }

        return items
    }

    private func exportPointsCSV() -> URL? {
        let bom = "\u{FEFF}"
        var csv = bom + "银行名称,积分名称,积分价值,币种代码\n"
        for p in points {
            let bank = p.bankName.replacingOccurrences(of: ",", with: "，")
            let name = p.pointName.replacingOccurrences(of: ",", with: "，")
            let value = String(format: "%.6f", p.pointValue)
            let currency = p.valueCurrencyCode.currencyCode
            csv += "\(bank),\(name),\(value),\(currency)\n"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let fileName = "Points_Backup_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("积分导出失败: \(error)")
            return nil
        }
    }
    
    private func clearAllData() {
        // 先取消所有卡片的待发通知，防止孤立提醒
        for card in cards {
            NotificationManager.shared.cancelNotification(for: card)
        }
        do {
            try deleteAll(of: Transaction.self)
            try deleteAll(of: CreditCard.self)
            try deleteAll(of: Point.self)
            try context.save()
            print("✅ All data cleared")
        } catch {
            print("❌ Failed to clear data: \(error)")
        }
    }

    private func deleteAll<T>(of type: T.Type) throws where T: SwiftData.PersistentModel {
        let descriptor = SwiftData.FetchDescriptor<T>()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "隐私政策"))
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 4)

                Text(String(localized: "我们重视你的隐私。以下为应用当前版本的隐私说明："))
                    .foregroundColor(.secondary)

                Text(String(localized: "• 数据存储：账单、卡片、积分等数据全部保存在你的设备本地，我们不上传任何个人数据。"))
                Text(String(localized: "• 网络请求：应用可能会为获取汇率、下载卡面等功能访问网络，仅下载必要参数。"))
                Text(String(localized: "• 权限使用：相机、相册、通知等权限仅在对应功能使用时申请，可在系统设置中随时关闭。"))
                Text(String(localized: "• 分享导出：仅当你主动使用\u{201C}导出\u{201D}功能时，数据才会通过系统导出面板离开应用。"))

                Text(String(localized: "若你对隐私相关内容有疑问，请联系开发者。"))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(String(localized: "隐私政策"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UpdateNotesView: View {
    let appVersion: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "更新版本注意事项"))
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 4)

                Text(String(localized: "当前版本：v\(appVersion)"))
                    .foregroundColor(.secondary)

                Text(String(localized: "• 更新前建议使用\u{201C}导出卡片与积分数据\u{201D}进行备份！！！（重要）。"))
                Text(String(localized: "• 更新后首次打开可能需要短暂时间完成数据整理。"))
                Text(String(localized: "• 若更新后出现应用闪退或异常的情况请删除应用，重新下载并导入之前备份的数据"))
                Text(String(localized: "• 若问题仍存在，请联系开发者协助排查。"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(String(localized: "更新注意事项"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
