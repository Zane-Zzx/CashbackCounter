import SwiftUI
import SwiftData

enum ReminderEventType: String {
    case repayment = "还款日"
    case statement = "账单日"
    case annualFee = "年费到期"
    case prepaidExpiry = "卡片到期"

    var localizedRawValue: LocalizedStringKey {
        switch self {
        case .repayment: return "还款日"
        case .statement: return "账单日"
        case .annualFee: return "年费到期"
        case .prepaidExpiry: return "卡片到期"
        }
    }

    var icon: String {
        switch self {
        case .repayment: return "clock.fill"
        case .statement: return "doc.text"
        case .annualFee: return "creditcard.and.123"
        case .prepaidExpiry: return "calendar.badge.clock"
        }
    }

    var color: Color {
        switch self {
        case .repayment: return .red
        case .statement: return .blue
        case .annualFee: return .orange
        case .prepaidExpiry: return .purple
        }
    }
}

struct ReminderEvent: Identifiable {
    let id = UUID()
    let card: CreditCard
    let type: ReminderEventType
    let date: Date?
    let dayOfMonth: Int?

    var sortDate: Date {
        if let date = date { return date }
        if let day = dayOfMonth, day > 0 {
            let cal = Calendar.current
            let now = Date()
            var comps = cal.dateComponents([.year, .month], from: now)
            let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 28
            comps.day = min(day, daysInMonth)
            guard var target = cal.date(from: comps) else { return .distantFuture }
            if target < cal.startOfDay(for: now) {
                guard let currentMonth = comps.month else { return .distantFuture }
                comps.month = currentMonth + 1
                let nextDate = cal.date(from: comps) ?? now
                let nextDays = cal.range(of: .day, in: .month, for: nextDate)?.count ?? 28
                comps.day = min(day, nextDays)
                guard let nextTarget = cal.date(from: comps) else { return .distantFuture }
                target = nextTarget
            }
            return target
        }
        return .distantFuture
    }

    var dateLabel: Text {
        if let date = date {
            return Text(date, format: .dateTime.year().month().day())
        }
        if let day = dayOfMonth {
            return Text("每月 \(day) 日")
        }
        return Text("")
    }
}

struct ReminderCenterView: View {
    @Query private var cards: [CreditCard]
    @Environment(\.modelContext) private var modelContext

    private var activeEvents: [ReminderEvent] {
        var result: [ReminderEvent] = []
        for card in cards where card.isRemindOpen {
            if card.cardKind.supportsBillingCycle {
                if card.repaymentDay > 0 {
                    result.append(ReminderEvent(card: card, type: .repayment, date: nil, dayOfMonth: card.repaymentDay))
                }
                if card.statementDay > 0 {
                    result.append(ReminderEvent(card: card, type: .statement, date: nil, dayOfMonth: card.statementDay))
                }
            }
            if card.cardKind.supportsAnnualFee, card.annualFee > 0, let expiry = card.benefitExpiryDate, Calendar.current.startOfDay(for: expiry) >= Calendar.current.startOfDay(for: Date()) {
                result.append(ReminderEvent(card: card, type: .annualFee, date: expiry, dayOfMonth: nil))
            }
            if card.cardKind.supportsBalance, let expiry = card.cardExpiryDate, Calendar.current.startOfDay(for: expiry) >= Calendar.current.startOfDay(for: Date()) {
                result.append(ReminderEvent(card: card, type: .prepaidExpiry, date: expiry, dayOfMonth: nil))
            }
        }
        return result.sorted { $0.sortDate < $1.sortDate }
    }

    private var disabledEvents: [ReminderEvent] {
        var result: [ReminderEvent] = []
        for card in cards where !card.isRemindOpen {
            if card.cardKind.supportsBillingCycle {
                if card.repaymentDay > 0 {
                    result.append(ReminderEvent(card: card, type: .repayment, date: nil, dayOfMonth: card.repaymentDay))
                }
                if card.statementDay > 0 {
                    result.append(ReminderEvent(card: card, type: .statement, date: nil, dayOfMonth: card.statementDay))
                }
            }
            if card.cardKind.supportsAnnualFee, card.annualFee > 0, let expiry = card.benefitExpiryDate, Calendar.current.startOfDay(for: expiry) >= Calendar.current.startOfDay(for: Date()) {
                result.append(ReminderEvent(card: card, type: .annualFee, date: expiry, dayOfMonth: nil))
            }
            if card.cardKind.supportsBalance, let expiry = card.cardExpiryDate, Calendar.current.startOfDay(for: expiry) >= Calendar.current.startOfDay(for: Date()) {
                result.append(ReminderEvent(card: card, type: .prepaidExpiry, date: expiry, dayOfMonth: nil))
            }
        }
        return result.sorted { $0.sortDate < $1.sortDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "暂无卡片",
                        systemImage: "creditcard",
                        description: Text("添加卡片后即可管理提醒")
                    )
                } else if activeEvents.isEmpty && disabledEvents.isEmpty {
                    ContentUnavailableView(
                        "暂无提醒",
                        systemImage: "bell.slash",
                        description: Text("为卡片设置还款日、账单日等信息后，提醒将自动出现")
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle(Text("提醒"))
        }
    }

    private var listContent: some View {
        List {
            cardOverviewSection

            let grouped = Dictionary(grouping: activeEvents) { event in
                Calendar.current.startOfDay(for: event.sortDate)
            }.sorted { $0.key < $1.key }

            ForEach(grouped, id: \.key) { date, dateEvents in
                Section {
                    ForEach(dateEvents) { event in
                        eventRow(event)
                    }
                } header: {
                    sectionHeader(for: date)
                }
            }

            if !disabledEvents.isEmpty {
                Section {
                    ForEach(disabledEvents) { event in
                        disabledEventRow(event)
                    }
                } header: {
                    Text("已关闭提醒")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var cardOverviewSection: some View {
        Section {
            ForEach(cards) { card in
                let cardEvents = (activeEvents + disabledEvents).filter { $0.card === card }
                if !cardEvents.isEmpty {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: card.colors),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 6, height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(card.bankName) \(card.type)")
                                .font(.subheadline.weight(.medium))
                            HStack(spacing: 8) {
                                ForEach(cardEvents) { event in
                                    Label {
                                        event.dateLabel
                                            .font(.caption2)
                                    } icon: {
                                        Image(systemName: event.type.icon)
                                            .font(.caption2)
                                            .foregroundStyle(event.type.color)
                                    }
                                }
                            }
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { card.isRemindOpen },
                            set: { newValue in
                                card.isRemindOpen = newValue
                                toggleReminders(for: card, on: newValue)
                            }
                        ))
                        .labelsHidden()
                        .scaleEffect(0.8)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("卡片提醒总览")
        }
    }

    private func eventRow(_ event: ReminderEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.title3)
                .foregroundStyle(event.type.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.card.bankName) + Text(" ") + Text(event.card.type) + Text(" ") + Text(event.type.localizedRawValue)
                    .font(.subheadline)
                event.dateLabel
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { event.card.isRemindOpen },
                set: { newValue in
                    event.card.isRemindOpen = newValue
                    toggleReminders(for: event.card, on: newValue)
                }
            ))
            .labelsHidden()
            .scaleEffect(0.8)
        }
        .padding(.vertical, 2)
    }

    private func disabledEventRow(_ event: ReminderEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.title3)
                .foregroundStyle(.gray)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.card.bankName) + Text(" ") + Text(event.card.type) + Text(" ") + Text(event.type.localizedRawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                event.dateLabel
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { event.card.isRemindOpen },
                set: { newValue in
                    event.card.isRemindOpen = newValue
                    toggleReminders(for: event.card, on: newValue)
                }
            ))
            .labelsHidden()
            .scaleEffect(0.8)
        }
        .padding(.vertical, 2)
    }

    private func sectionHeader(for date: Date) -> Text {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        if date == now { return Text("今天") }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), date == tomorrow { return Text("明天") }
        return Text(date, format: .dateTime.month().day())
    }

    private func toggleReminders(for card: CreditCard, on: Bool) {
        if on {
            NotificationManager.shared.syncReminders(for: card)
        } else {
            NotificationManager.shared.cancelNotification(for: card)
        }
    }
}
