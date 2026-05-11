import SwiftUI

enum CardKind: String, CaseIterable, Codable {
    case credit
    case debit
    case prepaid
    case atm

    var displayName: String {
        switch self {
        case .credit: return "card.kind.credit"
        case .debit: return "card.kind.debit"
        case .prepaid: return "card.kind.prepaid"
        case .atm: return "card.kind.atm"
        }
    }

    var iconName: String {
        switch self {
        case .credit: return "creditcard.fill"
        case .debit: return "banknote.fill"
        case .prepaid: return "ticket.fill"
        case .atm: return "arrow.up.arrow.down.circle.fill"
        }
    }

    var supportsBillingCycle: Bool { self == .credit }
    var supportsAnnualFee: Bool { self == .credit }
    var supportsFullRewards: Bool { self == .credit }
    var supportsSimpleRewards: Bool { self == .credit || self == .debit }
    var supportsBalance: Bool { self == .prepaid }
}
