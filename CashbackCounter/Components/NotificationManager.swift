import UserNotifications
import UIKit
import SwiftData

class NotificationManager {
    static let shared = NotificationManager()

    private func notificationId(for card: CreditCard, suffix: String = "") -> String {
        let base = "card_\(String(describing: card.persistentModelID))"
        return suffix.isEmpty ? base : "\(base)_\(suffix)"
    }

    // 1. 请求权限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已获取")
            } else {
                print("❌ 通知权限被拒绝")
            }
        }
    }
    
    // 2. 为卡片注册/更新通知
    func scheduleNotification(for card: CreditCard) {
        // 先取消旧的（防止重复）
        cancelNotification(for: card)
        
        // 如果还款日无效 (0)，则不注册
        guard card.isRemindOpen, card.repaymentDay > 0, card.repaymentDay <= 31 else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "还款提醒: \(card.bankName) \(card.type)"
        content.body = "今天是这张卡的还款日，别忘了处理账单哦！"
        content.sound = .default
        
        // 设置触发时间：每月的这一天，早上 9:00
        var dateComponents = DateComponents()
        dateComponents.day = card.repaymentDay
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        // repeats: true 代表每个月重复
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let identifier = notificationId(for: card)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 通知注册失败: \(error)")
            } else {
                print("✅ 已设定每月 \(card.repaymentDay) 日提醒: \(card.bankName)")
            }
        }
    }
    
    // 3. 取消通知 (用于删除卡片或关闭提醒时)
    func cancelNotification(for card: CreditCard) {
        let identifiers = [
            notificationId(for: card),
            notificationId(for: card, suffix: "statement"),
            notificationId(for: card, suffix: "annualfee"),
            notificationId(for: card, suffix: "prepaid")
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleStatementReminder(for card: CreditCard) {
        let identifier = notificationId(for: card, suffix: "statement")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        guard card.statementDay > 0, card.statementDay <= 31 else { return }

        let content = UNMutableNotificationContent()
        content.title = "账单日提醒: \(card.bankName) \(card.type)"
        content.body = "今天是这张卡的账单日，请查看账单明细。"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.day = card.statementDay
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("账单日通知注册失败: \(error)")
            }
        }
    }

    func scheduleAnnualFeeReminder(for card: CreditCard) {
        let identifier = notificationId(for: card, suffix: "annualfee")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        guard card.annualFee > 0, let expiry = card.benefitExpiryDate else { return }

        let cal = Calendar.current
        let now = Date()

        // 已过期，不再提醒
        guard cal.startOfDay(for: expiry) >= cal.startOfDay(for: now) else { return }

        let sevenDaysBefore = cal.date(byAdding: .day, value: -7, to: expiry) ?? expiry

        let fireDate: Date
        let isUrgent: Bool
        if cal.startOfDay(for: sevenDaysBefore) < cal.startOfDay(for: now) {
            // 7天提前量已过，但权益还没到期，立即触发
            fireDate = now.addingTimeInterval(5)
            isUrgent = true
        } else {
            fireDate = sevenDaysBefore
            isUrgent = false
        }

        let content = UNMutableNotificationContent()
        content.title = "年费提醒: \(card.bankName) \(card.type)"
        if cal.isDate(fireDate, inSameDayAs: expiry) || isUrgent {
            content.body = "这张卡的权益即将到期，年费 \(String(format: "%.0f", card.annualFee)) 元。"
        } else {
            content.body = "这张卡的权益将在 7 天后到期，年费 \(String(format: "%.0f", card.annualFee)) 元。"
        }
        content.sound = .default

        let trigger: UNNotificationTrigger
        if isUrgent {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        } else {
            var dateComponents = cal.dateComponents([.year, .month, .day], from: fireDate)
            dateComponents.hour = 9
            dateComponents.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("年费通知注册失败: \(error)")
            }
        }
    }

    func schedulePrepaidExpiryReminder(for card: CreditCard) {
        let identifier = notificationId(for: card, suffix: "prepaid")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let expiry = card.cardExpiryDate else { return }

        let cal = Calendar.current
        let now = Date()

        // 已过期，不再提醒
        guard cal.startOfDay(for: expiry) >= cal.startOfDay(for: now) else { return }

        let sevenDaysBefore = cal.date(byAdding: .day, value: -7, to: expiry) ?? expiry

        let fireDate: Date
        let isUrgent: Bool
        if cal.startOfDay(for: sevenDaysBefore) < cal.startOfDay(for: now) {
            // 7天提前量已过，但卡片还没到期，立即触发
            fireDate = now.addingTimeInterval(5)
            isUrgent = true
        } else {
            fireDate = sevenDaysBefore
            isUrgent = false
        }

        let content = UNMutableNotificationContent()
        content.title = "卡片到期提醒: \(card.bankName) \(card.type)"
        if cal.isDate(fireDate, inSameDayAs: expiry) || isUrgent {
            content.body = "这张预付卡即将到期，请及时处理余额。"
        } else {
            content.body = "这张预付卡将在 7 天后到期，请及时处理余额。"
        }
        content.sound = .default

        let trigger: UNNotificationTrigger
        if isUrgent {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        } else {
            var dateComponents = cal.dateComponents([.year, .month, .day], from: fireDate)
            dateComponents.hour = 9
            dateComponents.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("预付卡到期通知注册失败: \(error)") }
        }
    }

    func syncReminders(for card: CreditCard) {
        cancelNotification(for: card)
        guard card.isRemindOpen else { return }

        if card.cardKind.supportsBillingCycle {
            scheduleNotification(for: card)
            scheduleStatementReminder(for: card)
        }

        if card.cardKind.supportsAnnualFee {
            scheduleAnnualFeeReminder(for: card)
        }

        if card.cardKind.supportsBalance, card.cardExpiryDate != nil {
            schedulePrepaidExpiryReminder(for: card)
        }
    }
}
