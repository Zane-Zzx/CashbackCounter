import SwiftUI
import SwiftData

enum AddCardStep: Int, CaseIterable {
    case kind = 0
    case face = 1
    case billing = 2
    case rewards = 3
    case prepaidInfo = 4
}

struct CardDraft {
    var cardKind: CardKind = .credit
    var bankName: String = ""
    var cardType: String = ""
    var endNum: String = ""
    var cardNetwork: String = ""
    var region: Region = .cn
    var cardImageData: Data?
    var cardFaceSource: CardFaceSource = .gradient
    var color1: Color = .blue
    var color2: Color = .purple

    var statementDay: Int = 0
    var repaymentDay: Int = 0
    var annualFee: Double = 0
    var annualFeeWaiver: String = ""

    var defaultRate: Double = 1.0
    var foreignRate: Double?
    var rewardType: RewardType = .cashback
    var tags: [String] = []
    var notes: String = ""

    var balance: Double = 0
    var cardExpiryDate: Date? = nil
    var benefitExpiryDate: Date? = nil
}

struct AddCardWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step: AddCardStep = .kind
    @State private var draft = CardDraft()

    @Query(sort: [SortDescriptor(\Point.bankName, order: .forward)])
    private var points: [Point]
    @State private var selectedPointID: UUID?

    private var steps: [AddCardStep] {
        var result: [AddCardStep] = [.kind, .face]
        if draft.cardKind.supportsBillingCycle { result.append(.billing) }
        if draft.cardKind.supportsSimpleRewards { result.append(.rewards) }
        if draft.cardKind.supportsBalance { result.append(.prepaidInfo) }
        return result
    }

    private var currentStepIndex: Int {
        steps.firstIndex(of: step) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                ScrollView {
                    VStack(spacing: 20) {
                        switch step {
                        case .kind: kindStep
                        case .face: faceStep
                        case .billing: billingStep
                        case .rewards: rewardsStep
                        case .prepaidInfo: prepaidInfoStep
                        }
                    }
                    .padding()
                }
                navigationBar
            }
            .navigationTitle("添加卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(steps, id: \.self) { s in
                Circle()
                    .fill(s == step ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if currentStepIndex > 0 {
                Button("上一步") {
                    withAnimation { step = steps[currentStepIndex - 1] }
                }
            }
            Spacer()
            if currentStepIndex < steps.count - 1 {
                Button("下一步") {
                    withAnimation { step = steps[currentStepIndex + 1] }
                }
                .disabled(step == .face && (draft.bankName.isEmpty || draft.cardType.isEmpty))
            } else {
                Button("保存") { saveCard() }
                    .disabled(draft.bankName.isEmpty || draft.cardType.isEmpty)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - Kind Step

    private var kindStep: some View {
        VStack(spacing: 16) {
            Text("选择卡类型")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CardKind.allCases, id: \.self) { kind in
                    Button {
                        draft.cardKind = kind
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.iconName)
                                .font(.title)
                            Text(LocalizedStringKey(kind.displayName))
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(draft.cardKind == kind ? Color.blue.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(draft.cardKind == kind ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Face Step

    private var faceStep: some View {
        VStack(spacing: 16) {
            CardFacePickerView(
                cardImageData: $draft.cardImageData,
                color1: $draft.color1,
                color2: $draft.color2,
                cardFaceSource: $draft.cardFaceSource
            )

            GroupBox("基本信息") {
                VStack(spacing: 10) {
                    TextField("银行 (如: 招商银行)", text: $draft.bankName)
                    TextField("卡种 (如: 运通白金)", text: $draft.cardType)
                    TextField("尾号 (后四位)", text: $draft.endNum)
                        .keyboardType(.numberPad)
                        .onChange(of: draft.endNum) { _, newValue in
                            if newValue.count > 4 { draft.endNum = String(newValue.prefix(4)) }
                        }
                    Picker("卡组织", selection: $draft.cardNetwork) {
                        Text("未选择").tag("")
                        Text("Visa").tag("Visa")
                        Text("Mastercard").tag("Mastercard")
                        Text("银联").tag("UnionPay")
                        Text("Amex").tag("Amex")
                        Text("JCB").tag("JCB")
                        Text("其他").tag("Other")
                    }
                    Picker("发卡地区", selection: $draft.region) {
                        ForEach(Region.allCases, id: \.self) { r in
                            (Text(r.icon + " ") + Text(LocalizedStringKey(r.displayName))).tag(r)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Billing Step

    private var billingStep: some View {
        VStack(spacing: 16) {
            GroupBox("账单与还款") {
                VStack(spacing: 10) {
                    HStack {
                        Text("账单日")
                        Spacer()
                        TextField("无", value: $draft.statementDay, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("日").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("还款日")
                        Spacer()
                        TextField("无", value: $draft.repaymentDay, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("日").foregroundColor(.secondary)
                    }
                }
            }

            if draft.cardKind.supportsAnnualFee {
                GroupBox("年费") {
                    VStack(spacing: 10) {
                        HStack {
                            Text("年费")
                            Spacer()
                            TextField("0", value: $draft.annualFee, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        TextField("年费减免条件（选填）", text: $draft.annualFeeWaiver)
                        HStack {
                            DatePicker("权益到期日", selection: Binding(
                                get: { draft.benefitExpiryDate ?? Date() },
                                set: { draft.benefitExpiryDate = $0 }
                            ), displayedComponents: .date)
                            if draft.benefitExpiryDate != nil {
                                Button {
                                    draft.benefitExpiryDate = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rewards Step

    private var rewardsStep: some View {
        VStack(spacing: 16) {
            GroupBox("基础费率") {
                VStack(spacing: 10) {
                    HStack {
                        Text(draft.rewardType == .points ? "基础积分率 (%)" : "基础返现率 (%)")
                        Spacer()
                        TextField("1.0", value: $draft.defaultRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text(draft.rewardType == .points ? "外币积分率 (%)" : "外币返现率 (%)")
                        Spacer()
                        TextField("同本币", value: $draft.foreignRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
            }

            if draft.cardKind.supportsFullRewards {
                GroupBox("奖励类型") {
                    Picker("奖励类型", selection: $draft.rewardType) {
                        ForEach(RewardType.allCases, id: \.self) { t in
                            Text(LocalizedStringKey(t.displayName)).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    if draft.rewardType == .points {
                        Picker("选择积分计划", selection: $selectedPointID) {
                            Text("未选择").tag(UUID?.none)
                            ForEach(points) { point in
                                Text(point.displayName).tag(Optional(point.id))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Prepaid Info Step

    private var prepaidInfoStep: some View {
        VStack(spacing: 16) {
            GroupBox("卡片信息") {
                VStack(spacing: 10) {
                    HStack {
                        Text("当前余额")
                        Spacer()
                        TextField("0", value: $draft.balance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        DatePicker("到期日", selection: Binding(
                            get: { draft.cardExpiryDate ?? Date() },
                            set: { draft.cardExpiryDate = $0 }
                        ), displayedComponents: .date)
                        if draft.cardExpiryDate != nil {
                            Button {
                                draft.cardExpiryDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveCard() {
        let c1Hex = draft.color1.toHex() ?? "0000FF"
        let c2Hex = draft.color2.toHex() ?? "000000"
        let kind = draft.cardKind

        let resolvedPoint = kind.supportsFullRewards && draft.rewardType == .points
            ? points.first { $0.id == selectedPointID } : nil

        let newCard = CreditCard(
            bankName: draft.bankName,
            type: draft.cardType,
            endNum: draft.endNum,
            colorHexes: [c1Hex, c2Hex],
            defaultRate: kind.supportsSimpleRewards ? draft.defaultRate / 100.0 : 0,
            specialRates: [:],
            issueRegion: draft.region,
            foreignCurrencyRate: kind.supportsSimpleRewards ? draft.foreignRate.map { $0 / 100.0 } : nil,
            localBaseCap: 0,
            foreignBaseCap: 0,
            categoryCaps: [:],
            capPeriod: .yearly,
            repaymentDay: kind.supportsBillingCycle ? max(0, min(31, draft.repaymentDay)) : 0,
            paymentMethodRates: [:],
            paymentCaps: [:],
            rewardType: kind.supportsFullRewards ? draft.rewardType : .cashback,
            pointProgram: resolvedPoint,
            cardImageData: draft.cardImageData,
            cardNetwork: draft.cardNetwork,
            statementDay: kind.supportsBillingCycle ? max(0, min(31, draft.statementDay)) : 0,
            annualFee: kind.supportsAnnualFee ? draft.annualFee : 0,
            annualFeeWaiver: kind.supportsAnnualFee ? draft.annualFeeWaiver : "",
            tags: draft.tags,
            notes: draft.notes,
            benefitExpiryDate: kind.supportsAnnualFee ? draft.benefitExpiryDate : nil,
            balance: kind.supportsBalance ? draft.balance : 0,
            cardExpiryDate: kind.supportsBalance ? draft.cardExpiryDate : nil,
            cardKind: kind,
            cardFaceSource: draft.cardFaceSource
        )
        modelContext.insert(newCard)
        NotificationManager.shared.syncReminders(for: newCard)
        dismiss()
    }
}
