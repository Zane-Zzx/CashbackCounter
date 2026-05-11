import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: CreditCard
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CreditCardView(
                    bankName: card.bankName,
                    type: card.type,
                    endNum: card.endNum,
                    colors: card.colors,
                    cardImageData: card.cardImageData,
                    displayHeight: 220
                )
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)

                basicInfoSection
                tagsSection
                if card.cardKind.supportsBillingCycle && (card.statementDay > 0 || card.repaymentDay > 0 || card.benefitExpiryDate != nil) { datesSection }
                if card.cardKind.supportsAnnualFee { annualFeeSection }
                if card.cardKind.supportsSimpleRewards { rulesSection }
                if card.cardKind.supportsFullRewards { pointsSection }
                if card.cardKind.supportsBalance && (card.balance > 0 || card.cardExpiryDate != nil) {
                    prepaidSection
                }
                notesSection
            }
            .padding(.bottom, 80)
        }
        .navigationTitle(card.bankName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showEditSheet = true } label: {
                    Image(systemName: "pencil.circle.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddCardView(cardToEdit: card)
        }
        .confirmationDialog("确定要删除这张卡片吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                NotificationManager.shared.cancelNotification(for: card)
                modelContext.delete(card)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var basicInfoSection: some View {
        Section {
            VStack(spacing: 10) {
                row("卡类型", value: card.cardKind.displayName)
                row("银行", value: card.bankName)
                row("卡种", value: card.type)
                row("尾号", value: "**** \(card.endNum)")
                if !card.cardNetwork.isEmpty {
                    row("卡组织", value: String(localized: LocalizedStringResource(stringLiteral: card.cardNetwork)))
                }
                row("发卡地区", value: "\(card.issueRegion.icon) \(card.issueRegion.displayName)")
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        } header: {
            sectionHeader("基本信息")
        }
    }

    private var tagsSection: some View {
        Group {
            if !card.tags.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(card.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                } header: {
                    sectionHeader("标签")
                }
            }
        }
    }

    private var datesSection: some View {
        Section {
            VStack(spacing: 10) {
                if card.statementDay > 0 {
                    row("账单日", value: "\(String(localized: "每月")) \(card.statementDay) \(String(localized: "日"))")
                }
                if card.repaymentDay > 0 {
                    row("还款日", value: "\(String(localized: "每月")) \(card.repaymentDay) \(String(localized: "日"))")
                }
                if let expiry = card.benefitExpiryDate {
                    row("权益到期", value: expiry.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        } header: {
            sectionHeader("关键日期")
        }
    }

    private var annualFeeSection: some View {
        Group {
            if card.annualFee > 0 || !card.annualFeeWaiver.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        if card.annualFee > 0 {
                            row("年费", value: String(format: "%@%.0f", card.issueRegion.currencySymbol, card.annualFee))
                        }
                        if !card.annualFeeWaiver.isEmpty {
                            row("减免条件", value: card.annualFeeWaiver)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                } header: {
                    sectionHeader("年费")
                }
            }
        }
    }

    private var rulesSection: some View {
        Section {
            VStack(spacing: 10) {
                row("基础费率", value: String(format: "%.2f%%", card.defaultRate * 100))

                if let fr = card.foreignCurrencyRate, fr > 0 {
                    row("外币费率", value: String(format: "%.2f%%", fr * 100))
                }

                if !card.specialRates.isEmpty {
                    Divider()
                    Text("类别加成").font(.caption).foregroundColor(.secondary)
                    ForEach(Array(card.specialRates.sorted { $0.key.rawValue < $1.key.rawValue }), id: \.key) { cat, rate in
                        HStack {
                            Label { Text(LocalizedStringKey(cat.displayName)) } icon: { Image(systemName: cat.iconName) }
                                .foregroundColor(cat.color)
                            Spacer()
                            Text(String(format: "+%.2f%%", rate * 100))
                                .foregroundColor(.green)
                        }
                        if let cap = card.categoryCaps[cat], cap > 0 {
                            Text("\(String(localized: "上限:"))\(String(format: "%.0f", cap))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !card.paymentMethodRates.isEmpty {
                    Divider()
                    Text("支付方式加成").font(.caption).foregroundColor(.secondary)
                    ForEach(Array(card.paymentMethodRates.sorted { $0.key.rawValue < $1.key.rawValue }), id: \.key) { method, rate in
                        HStack {
                            Label { Text(LocalizedStringKey(method.displayName)) } icon: { Image(systemName: method.iconName) }
                                .foregroundColor(method.color)
                            Spacer()
                            Text(String(format: "+%.2f%%", rate * 100))
                                .foregroundColor(.green)
                        }
                        if let cap = card.paymentCaps[method], cap > 0 {
                            Text("\(String(localized: "上限:"))\(String(format: "%.0f", cap))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if card.localBaseCap > 0 || card.foreignBaseCap > 0 {
                    Divider()
                    if card.localBaseCap > 0 {
                        row("本币上限", value: String(format: "%.0f", card.localBaseCap))
                    }
                    if card.foreignBaseCap > 0 {
                        row("外币上限", value: String(format: "%.0f", card.foreignBaseCap))
                    }
                }

                row("返现类型", value: card.rewardType.displayName)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        } header: {
            sectionHeader("权益规则")
        }
    }

    @ViewBuilder
    private var pointsSection: some View {
        if card.rewardType == .points, let point = card.pointProgram {
            Section {
                VStack(spacing: 10) {
                    row("积分名称", value: point.pointName)
                    row("积分银行", value: point.bankName)
                    row("积分价值", value: String(format: "%.6f", point.pointValue))
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            } header: {
                sectionHeader("积分计划")
            }
        }
    }

    private var prepaidSection: some View {
        Group {
            if card.cardKind.supportsBalance {
                Section {
                    VStack(spacing: 10) {
                        if card.balance > 0 {
                            row("余额", value: String(format: "%@%.2f", card.issueRegion.currencySymbol, card.balance))
                        }
                        if let expiry = card.cardExpiryDate {
                            row("到期日", value: expiry.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                } header: {
                    sectionHeader("卡片信息")
                }
            }
        }
    }

    private var notesSection: some View {
        Group {
            if !card.notes.isEmpty {
                Section {
                    Text(card.notes)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                } header: {
                    sectionHeader("备注")
                }
            }
        }
    }

    private func row(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
}
