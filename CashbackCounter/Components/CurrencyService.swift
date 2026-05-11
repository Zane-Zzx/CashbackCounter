import Foundation

// 1. 定义 API 响应结构 (适配动态币种键)
struct FrankfurterLatestResponse: Decodable {
    let date: String
    let base: String
    let rates: [String: Double]

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)

        let dateKey = DynamicKey(stringValue: "date")!
        date = try container.decode(String.self, forKey: dateKey)

        guard let baseKey = container.allKeys.first(where: { $0.stringValue != "date" }) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Missing dynamic currency key")
            )
        }

        base = baseKey.stringValue
        rates = try container.decode([String: Double].self, forKey: baseKey)
    }
}

struct CurrencyService {

    // --- 缓存配置 ---
    private static let kRatesKey = "cached_exchange_rates"
    private static let kDateKey = "last_fetch_date"
    private static let kBaseKey = "last_rates_base"

    private struct CachedRates: Codable {
        let base: String
        let rates: [String: Double]
    }

    // --- 🚀 智能入口：获取汇率 ---
    static func getRates(base: String = "CNY") async -> [String: Double] {
        print(base)
        if
            let lastDate = UserDefaults.standard.object(forKey: kDateKey) as? Date,
            let lastBase = UserDefaults.standard.string(forKey: kBaseKey),
            lastBase == base,
            Calendar.current.isDateInToday(lastDate)
        {
            if let cachedRates = loadLocalRates() {
                print("✅ 汇率无需更新，使用本地缓存 (\(base))")
                return cachedRates.rates
            }
        }

        print("🌍 正在联网更新汇率 (base: \(base))...")
        do {
            let rates = try await fetchRemoteRates(base: base)
            saveRatesLocally(rates, base: base)
            return rates
        } catch {
            print("❌ 网络请求失败: \(error)")
            if let cached = loadLocalRates(), cached.base.caseInsensitiveCompare(base) == .orderedSame {
                return cached.rates
            }
            return [base: 1.0]
        }
    }

    /// 同步转换（仅用缓存，无缓存返回原值）
    static func convertSync(_ amount: Double, from fromCurrency: String, to toCurrency: String) -> Double {
        if fromCurrency == toCurrency { return amount }
        guard let cached = loadLocalRates(),
              cached.base.caseInsensitiveCompare(fromCurrency) == .orderedSame else { return amount }
        let key = toCurrency.lowercased()
        guard let rate = cached.rates[key] else { return amount }
        return amount * rate
    }

    /// 将 amount 从 fromCurrency 转换为 toCurrency
    static func convert(_ amount: Double, from fromCurrency: String, to toCurrency: String) async -> Double {
        if fromCurrency == toCurrency { return amount }
        let rates = await getRates(base: fromCurrency)
        if let rate = rates[toCurrency.lowercased()] {
            return amount * rate
        }
        return amount
    }

    // --- 内部方法：联网下载 (私有) ---
    private static func fetchRemoteRates(base: String) async throws -> [String: Double] {
        let urlString = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/\(base.lowercased()).json"
        guard let url = URL(string: urlString) else { return [:] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterLatestResponse.self, from: data)
        return response.rates
    }

    // --- 内部方法：存入 UserDefaults ---
    private static func saveRatesLocally(_ rates: [String: Double], base: String) {
        let cached = CachedRates(base: base, rates: rates)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: kRatesKey)
        }
        UserDefaults.standard.set(Date(), forKey: kDateKey)
        UserDefaults.standard.set(base, forKey: kBaseKey)
    }

    // --- 内部方法：读取 UserDefaults ---
    private static func loadLocalRates() -> CachedRates? {
        guard let data = UserDefaults.standard.data(forKey: kRatesKey) else { return nil }
        return try? JSONDecoder().decode(CachedRates.self, from: data)
    }

}
