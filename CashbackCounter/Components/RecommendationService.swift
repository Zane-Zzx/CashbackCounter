import Foundation

struct CardRecommendation: Identifiable {
    let id = UUID()
    let card: CreditCard
    let effectiveRate: Double
    let estimatedReward: Double
    let normalizedReward: Double
    let isPoints: Bool
    let pointsEarned: Int
    let rewardCurrencySymbol: String
}

struct RecommendationService {
    static func recommend(
        cards: [CreditCard],
        category: Category,
        region: Region,
        payment: PaymentMethod,
        amount: Double = 100,
        targetCurrency: String = "CNY"
    ) -> [CardRecommendation] {
        let eligible = cards.filter { $0.cardKind.supportsSimpleRewards }

        return eligible.compactMap { card -> CardRecommendation? in
            let rate = card.getRate(for: category, location: region, payment: payment)
            guard rate > 0 else { return nil }

            let isPoints = card.rewardType == .points && card.pointProgram != nil
            let cardCurrency = card.issueRegion.currencyCode
            let currencySymbol = card.issueRegion.currencySymbol

            let estimatedReward: Double
            let pointsEarned: Int

            if isPoints, let pointProgram = card.pointProgram {
                pointsEarned = Int(amount * rate)
                estimatedReward = Double(pointsEarned) * pointProgram.pointValue
            } else {
                estimatedReward = amount * rate
                pointsEarned = 0
            }

            let normalizedReward = CurrencyService.convertSync(
                estimatedReward, from: cardCurrency, to: targetCurrency
            )

            return CardRecommendation(
                card: card,
                effectiveRate: rate,
                estimatedReward: estimatedReward,
                normalizedReward: normalizedReward,
                isPoints: isPoints,
                pointsEarned: pointsEarned,
                rewardCurrencySymbol: currencySymbol
            )
        }.sorted { $0.normalizedReward > $1.normalizedReward }
    }
}
