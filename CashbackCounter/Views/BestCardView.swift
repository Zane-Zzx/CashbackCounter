import SwiftUI
import SwiftData

struct BestCardView: View {
    @Query private var cards: [CreditCard]

    @State private var selectedCategory: Category = .dining
    @State private var selectedRegion: Region = .cn
    @State private var selectedPayment: PaymentMethod = .offline
    @State private var amountText: String = "100"

    @AppStorage("visibleRegions") private var visibleRegionsData: Data = Data()
    @AppStorage("mainCurrencyCode") private var mainCurrencyCode: String = "CNY"

    private var visibleRegions: [Region] {
        guard let decoded = try? JSONDecoder().decode([String].self, from: visibleRegionsData),
              !decoded.isEmpty else {
            return Region.allCases
        }
        return decoded.compactMap { Region(rawValue: $0) }
    }

    private var currencySymbol: String {
        Region.allCases.first { $0.currencyCode == mainCurrencyCode }?.currencySymbol ?? "¥"
    }

    private var amount: Double {
        Double(amountText) ?? 0
    }

    private var recommendations: [CardRecommendation] {
        guard amount > 0 else { return [] }
        return RecommendationService.recommend(
            cards: cards,
            category: selectedCategory,
            region: selectedRegion,
            payment: selectedPayment,
            amount: amount,
            targetCurrency: mainCurrencyCode
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sceneSelectionSection
                    recommendationListSection
                }
                .padding()
            }
            .navigationTitle("推荐")
            .onAppear {
                if !visibleRegions.contains(selectedRegion) {
                    selectedRegion = visibleRegions.first ?? .cn
                }
            }
            .onChange(of: visibleRegions) { _, newRegions in
                if !newRegions.contains(selectedRegion) {
                    selectedRegion = newRegions.first ?? .cn
                }
            }
        }
    }

    // MARK: - 场景选择

    private var sceneSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("消费场景")
                .font(.headline)

            // 类别 chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Category.uiCases, id: \.self) { cat in
                        Button { selectedCategory = cat } label: {
                            Label { Text(LocalizedStringKey(cat.displayName)) } icon: { Image(systemName: cat.iconName) }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == cat ? cat.color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                                .foregroundColor(selectedCategory == cat ? cat.color : .secondary)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 地区 chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleRegions, id: \.self) { region in
                        Button { selectedRegion = region } label: {
                            (Text(region.icon + " ") + Text(LocalizedStringKey(region.displayName)))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedRegion == region ? Color.accentColor.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                                .foregroundColor(selectedRegion == region ? .accentColor : .secondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 支付方式 chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PaymentMethod.allCases.filter(\.isGeneral), id: \.self) { method in
                        Button { selectedPayment = method } label: {
                            Label { Text(LocalizedStringKey(method.displayName)) } icon: { Image(systemName: method.iconName) }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedPayment == method ? method.color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                                .foregroundColor(selectedPayment == method ? method.color : .secondary)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 金额输入
            HStack {
                Text("消费金额")
                    .font(.subheadline)
                Spacer()
                TextField("100", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text(selectedRegion.currencySymbol)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 推荐列表

    private var recommendationListSection: some View {
        VStack(spacing: 0) {
            HStack {
                Label("推荐结果", systemImage: "list.number")
                    .font(.headline)
                Spacer()
                Text("\(recommendations.count) 张卡片")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .padding(.bottom, 12)

            if recommendations.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                        recommendationRow(rec, rank: index)
                        if index < recommendations.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("没有符合条件的卡片")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func recommendationRow(_ rec: CardRecommendation, rank: Int) -> some View {
        let isTop = rank == 0

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isTop ? Color.yellow.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 36, height: 36)
                if isTop {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                } else {
                    Text("\(rank + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(rec.card.bankName) \(rec.card.type)")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !rec.card.endNum.isEmpty {
                        Text(rec.card.endNum)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if selectedRegion != rec.card.issueRegion {
                        if let fr = rec.card.foreignCurrencyRate, fr > 0 {
                            Text("外币\(String(format: "%.2f%%", fr * 100))")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else {
                            Text("未设外币费率")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    if rec.isPoints {
                        Text("积分")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f%%", rec.effectiveRate * 100))
                    .font(.subheadline.bold())
                    .foregroundStyle(rateColor(for: rec.effectiveRate))
                Text(String(format: "≈%@ %.2f", rec.rewardCurrencySymbol, rec.estimatedReward))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .if(isTop) { view in
            view
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1.5)
                        .padding(.horizontal, 4)
                )
        }
    }

    // MARK: - Helpers

    private func rateColor(for rate: Double) -> Color {
        switch rate {
        case 0.05...: return .green
        case 0.02..<0.05: return .blue
        default: return .primary
        }
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
