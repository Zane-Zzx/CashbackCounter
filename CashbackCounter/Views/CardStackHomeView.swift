import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum AddCardSheetType: Identifiable {
    case template
    case custom
    var id: Int { hashValue }
}

private struct CardStackMetrics {
    let horizontalPadding: CGFloat = 16
    let collapsedSpacing: CGFloat = 100
    let collapsedTop: CGFloat = 20
    let expandedTopOffset: CGFloat = 10

    let cardWidth: CGFloat
    let cardHeight: CGFloat

    let detailSpacing: CGFloat = 8

    var detailTop: CGFloat { expandedTopOffset + cardHeight + detailSpacing }
    var tapOverlayTop: CGFloat { expandedTopOffset }
    var tapOverlayHeight: CGFloat { cardHeight }
    var contentHeight: CGFloat { CGFloat(max(1, cardCount)) * collapsedSpacing + collapsedTop + cardHeight }

    let cardCount: Int

    init(screenWidth: CGFloat, cardCount: Int) {
        self.cardWidth = screenWidth - 2 * horizontalPadding
        self.cardHeight = cardWidth / 1.586
        self.cardCount = cardCount
    }
}

struct CardStackHomeView: View {
    @Query(sort: [SortDescriptor(\CreditCard.bankName, order: .forward)])
    var cards: [CreditCard]
    @Environment(\.modelContext) var context

    @State private var activeSheet: AddCardSheetType?
    @State private var cardToEdit: CreditCard?
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var showImportAlert = false
    @State private var filterKind: CardKind?

    @State private var selectedCardID: PersistentIdentifier?
    @State private var scrollOffset: CGFloat = 0

    private let springAnimation = Animation.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)

    private var isDetailMode: Bool { selectedCardID != nil }

    var filteredCards: [CreditCard] {
        if let kind = filterKind {
            return cards.filter { $0.cardKind == kind }
        }
        return cards
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if cards.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        filterChips
                        if filteredCards.isEmpty {
                            ContentUnavailableView {
                                Label("没有\(filterKind?.displayName ?? String(localized: "卡片"))", systemImage: "creditcard")
                            } description: {
                                Text("试试其他筛选条件或添加新卡片")
                            }
                        } else {
                            cardStack
                        }
                    }
                    .navigationTitle(isDetailMode
                        ? (filteredCards.first(where: { $0.id == selectedCardID })?.bankName ?? "我的卡包")
                        : "我的卡包")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .opacity(isDetailMode ? 0 : 1)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isDetailMode, let card = filteredCards.first(where: { $0.id == selectedCardID }) {
                        Menu {
                            Button { cardToEdit = card } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                NotificationManager.shared.cancelNotification(for: card)
                                context.delete(card)
                                withAnimation(springAnimation) { selectedCardID = nil }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    } else {
                        Menu {
                            Button { activeSheet = .template } label: {
                                Label("从模板添加", systemImage: "doc.on.doc")
                            }
                            Button { activeSheet = .custom } label: {
                                Label("自定义添加", systemImage: "square.and.pencil")
                            }
                            Divider()
                            if !cards.isEmpty, let csvURL = cards.exportCSVFile() {
                                ShareLink(item: csvURL) {
                                    Label("导出卡片", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { type in
                switch type {
                case .template: CardTemplateListView(rootSheet: toSheetBinding())
                case .custom: AddCardWizardView()
                }
            }
            .sheet(item: $cardToEdit) { card in
                AddCardView(cardToEdit: card)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        let csvType = CardCSVHelper.detectCSVType(content: content)
                        switch csvType {
                        case .cards:
                            try CardCSVHelper.parseCSV(content: content, into: context)
                            importError = nil
                        case .points:
                            try CardCSVHelper.parsePointsCSV(content: content, into: context)
                            importError = nil
                        case .unknown:
                            importError = String(localized: "导入失败：无法识别的 CSV 格式。请使用应用导出的卡片或积分 CSV 文件。")
                            showImportAlert = true
                        }
                    } catch {
                        importError = String(localized: "导入失败：格式错误或文件损坏。\n\(error.localizedDescription)")
                        showImportAlert = true
                    }
                case .failure(let error):
                    print("选择文件失败: \(error.localizedDescription)")
                }
            }
            .alert("导入结果", isPresented: $showImportAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(importError ?? String(localized: "未知错误"))
            }
            .onAppear {
                do {
                    try CardTemplate.syncDefaultTemplates(in: context)
                } catch {
                    print("Failed to sync card templates: \(error)")
                }
            }
            .onChange(of: filterKind) { _, _ in
                withAnimation(springAnimation) { selectedCardID = nil }
            }
            .onChange(of: filteredCards.map { $0.id }) { _, newIDs in
                if let selected = selectedCardID, !newIDs.contains(selected) {
                    withAnimation(springAnimation) { selectedCardID = nil }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有卡片", systemImage: "creditcard")
        } description: {
            Text("点击右上角 + 添加你的第一张银行卡")
        }
    }

    // MARK: - 卡片堆叠

    private var cardStack: some View {
        GeometryReader { geometry in
            let metrics = CardStackMetrics(screenWidth: geometry.size.width, cardCount: filteredCards.count)

            ZStack(alignment: .top) {
                // 底层：展开后的详情内容
                if let selectedCard = filteredCards.first(where: { $0.id == selectedCardID }) {
                    ScrollView(showsIndicators: false) {
                        cardDetailContent(for: selectedCard)
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                    }
                    .padding(.top, metrics.detailTop)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(0)
                }

                // 顶层：卡片堆叠
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .top) {
                        ForEach(Array(filteredCards.enumerated()), id: \.element.id) { index, card in
                            let isSelected = card.id == selectedCardID
                            CreditCardView(
                                bankName: card.bankName,
                                type: card.type,
                                endNum: card.endNum,
                                colors: card.colors,
                                cardImageData: card.cardImageData,
                                displayWidth: metrics.cardWidth
                            )
                            .contentShape(Rectangle())
                            .offset(y: isSelected
                                ? (scrollOffset + metrics.expandedTopOffset)
                                : (isDetailMode ? 800 : CGFloat(index) * metrics.collapsedSpacing + metrics.collapsedTop))
                            .opacity(isDetailMode && !isSelected ? 0 : 1)
                            .scaleEffect(isDetailMode && !isSelected ? 0.9 : 1)
                            .zIndex(isSelected ? 100 : Double(filteredCards.count - index))
                            .shadow(color: .black.opacity(isDetailMode ? 0.2 : 0.1), radius: isDetailMode ? 20 : 10, x: 0, y: 5)
                            .onTapGesture {
                                withAnimation(springAnimation) {
                                    if isSelected {
                                        selectedCardID = nil
                                    } else {
                                        selectedCardID = card.id
                                    }
                                }
                            }
                        }
                        Color.clear.frame(height: metrics.contentHeight)
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newValue in
                    if !isDetailMode { scrollOffset = newValue }
                }
                .scrollDisabled(isDetailMode)
                .allowsHitTesting(!isDetailMode)
                .zIndex(1)

                // 点击关闭层
                if isDetailMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: metrics.tapOverlayHeight)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.tapOverlayTop)
                        .zIndex(2)
                        .onTapGesture {
                            withAnimation(springAnimation) { selectedCardID = nil }
                        }
                }
            }
        }
    }

    // MARK: - 卡片详情摘要

    @ViewBuilder
    private func cardDetailContent(for card: CreditCard) -> some View {
        VStack(spacing: 12) {
            // 操作按钮行
            HStack(spacing: 16) {
                Button { cardToEdit = card } label: {
                    Label("编辑", systemImage: "pencil.circle.fill")
                }
                NavigationLink { CardDetailView(card: card) } label: {
                    Label("详情", systemImage: "info.circle.fill")
                }
                Spacer()
                Button(role: .destructive) {
                    NotificationManager.shared.cancelNotification(for: card)
                    context.delete(card)
                    withAnimation(springAnimation) { selectedCardID = nil }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }

            Divider()

            // 基本信息
            HStack {
                Label(card.cardKind.displayName, systemImage: card.cardKind.iconName)
                    .font(.subheadline)
                if !card.cardNetwork.isEmpty {
                    Text("·")
                    Text(String(localized: LocalizedStringResource(stringLiteral: card.cardNetwork)))
                }
                Spacer()
                if !card.endNum.isEmpty {
                    Text("\(String(localized: "尾号"))\(card.endNum)")
                        .foregroundStyle(.secondary)
                }
            }

            // 返现信息
            if card.cardKind.supportsSimpleRewards {
                HStack {
                    Text("基础费率")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f%%", card.defaultRate * 100))
                        .bold()
                }

                if let fr = card.foreignCurrencyRate, fr > 0 {
                    HStack {
                        Text("外币费率")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f%%", fr * 100))
                            .bold()
                            .foregroundStyle(.green)
                    }
                }

                if !card.specialRates.isEmpty {
                    Divider()
                    ForEach(Array(card.specialRates.sorted { $0.key.rawValue < $1.key.rawValue }), id: \.key) { cat, rate in
                        HStack {
                            Label(cat.displayName, systemImage: cat.iconName)
                                .foregroundStyle(cat.color)
                            Spacer()
                            Text(String(format: "+%.2f%%", rate * 100))
                                .foregroundStyle(.green)
                        }
                    }
                }

                HStack {
                    Text("奖励类型")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(card.rewardType.displayName)
                }
            }

            // 关键日期
            if card.cardKind.supportsBillingCycle {
                if card.statementDay > 0 || card.repaymentDay > 0 {
                    Divider()
                    HStack {
                        if card.statementDay > 0 {
                            Text("\(String(localized: "账单日")) \(card.statementDay)\(String(localized: "日"))")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if card.repaymentDay > 0 {
                            Text("\(String(localized: "还款日")) \(card.repaymentDay)\(String(localized: "日"))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 年费
            if card.cardKind.supportsAnnualFee && (card.annualFee > 0 || !card.annualFeeWaiver.isEmpty) {
                HStack {
                    Text("年费")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if card.annualFee > 0 {
                        Text(String(format: "%@%.0f", card.issueRegion.currencySymbol, card.annualFee))
                    }
                }
                if !card.annualFeeWaiver.isEmpty {
                    Text("\(String(localized: "减免: "))\(card.annualFeeWaiver)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 标签
            if !card.tags.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(card.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 筛选栏

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(label: String(localized: "全部"), isSelected: filterKind == nil) {
                    filterKind = nil
                }
                ForEach(CardKind.allCases, id: \.self) { kind in
                    filterChip(
                        label: kind.displayName,
                        icon: kind.iconName,
                        isSelected: filterKind == kind
                    ) {
                        filterKind = kind
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func filterChip(label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color(uiColor: .separator).opacity(0.5), lineWidth: 1)
            )
        }
    }

    private func toSheetBinding() -> Binding<SheetType?> {
        Binding<SheetType?>(
            get: {
                if let active = activeSheet {
                    switch active {
                    case .template: return .template
                    case .custom: return .custom
                    }
                }
                return nil
            },
            set: { newValue in
                if let newValue = newValue {
                    switch newValue {
                    case .template: activeSheet = .template
                    case .custom: activeSheet = .custom
                    }
                } else {
                    activeSheet = nil
                }
            }
        )
    }
}
