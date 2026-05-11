import Foundation
import SwiftUI
import SwiftData

// MARK: - CSV Row Parsing (RFC 4180 compliant state machine)

struct CardCSVHelper {

    // Header includes extended fields
    static let header = "银行名称,卡种名称,尾号,颜色1(Hex),颜色2(Hex),地区(Code),本币返现率(%),外币返现率(%),本币上限,外币上限,餐饮加成(%),超市加成(%),出行加成(%),数码加成(%),其他加成(%),餐饮上限,超市上限,出行上限,数码上限,其他上限,上限周期(monthly/yearly),还款日,支付方式加成(代码:rate),支付方式上限(代码:cap),奖励类型,积分名称,积分银行,积分价值,积分币种,卡类型(cardKind),卡组织,账单日,年费,年费减免,标签,备注,余额,权益到期日,卡片到期日,卡面来源"

    // Points CSV header
    static let pointsHeader = "银行名称,积分名称,积分价值,币种代码"

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Export Cards
    static func generateCSV(from cards: [CreditCard]) -> String {
        var csvString = "\u{FEFF}" + header + "\n"

        for card in cards {
            let bank = card.bankName.replacingOccurrences(of: ",", with: "，")
            let type = card.type.replacingOccurrences(of: ",", with: "，")
            let endNum = card.endNum

            let c1 = card.colorHexes.first ?? "0000FF"
            let c2 = card.colorHexes.last ?? "000000"

            let region = card.issueRegion.rawValue
            let defRate = String(format: "%.2f", card.defaultRate * 100)
            let forRate = card.foreignCurrencyRate != nil ? String(format: "%.2f", card.foreignCurrencyRate! * 100) : ""
            let locCap = card.localBaseCap > 0 ? String(format: "%.0f", card.localBaseCap) : ""
            let forCap = card.foreignBaseCap > 0 ? String(format: "%.0f", card.foreignBaseCap) : ""

            let diningRate = fmtRate(card.specialRates[.dining])
            let groceryRate = fmtRate(card.specialRates[.grocery])
            let travelRate = fmtRate(card.specialRates[.travel])
            let digitalRate = fmtRate(card.specialRates[.digital])
            let otherRate = fmtRate(card.specialRates[.other])

            let diningCap = fmtCap(card.categoryCaps[.dining])
            let groceryCap = fmtCap(card.categoryCaps[.grocery])
            let travelCap = fmtCap(card.categoryCaps[.travel])
            let digitalCap = fmtCap(card.categoryCaps[.digital])
            let otherCap = fmtCap(card.categoryCaps[.other])

            let rDay = card.repaymentDay > 0 ? String(card.repaymentDay) : ""
            let capPeriodStr: String
            switch card.capPeriod {
            case .monthly: capPeriodStr = "monthly"
            case .yearly:  capPeriodStr = "yearly"
            }

            let pmRatesStr = card.paymentMethodRates.map {
                "\($0.key.rawValue):\(String(format: "%.2f", $0.value * 100))"
            }.joined(separator: "|")

            let pmCapsStr = card.paymentCaps.map {
                "\($0.key.rawValue):\(String(format: "%.0f", $0.value))"
            }.joined(separator: "|")

            let rewardTypeStr = card.rewardType.rawValue
            let pointName = card.pointProgram?.pointName ?? ""
            let pointBank = card.pointProgram?.bankName ?? ""
            let pointValue = card.pointProgram != nil ? String(format: "%.6f", card.pointProgram?.pointValue ?? 0) : ""
            let pointCurrency = card.pointProgram?.valueCurrencyCode.currencyCode ?? ""

            // Extended fields
            let cardKindStr = card.cardKind.rawValue
            let cardNetworkStr = card.cardNetwork
            let statementDayStr = card.statementDay > 0 ? String(card.statementDay) : ""
            let annualFeeStr = card.annualFee > 0 ? String(format: "%.0f", card.annualFee) : ""
            let annualFeeWaiverStr = card.annualFeeWaiver
            let tagsStr = (try? JSONEncoder().encode(card.tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let notesStr = card.notes
            let balanceStr = card.balance > 0 ? String(format: "%.2f", card.balance) : ""
            let benefitExpiryStr = card.benefitExpiryDate.map { isoFormatter.string(from: $0) } ?? ""
            let cardExpiryStr = card.cardExpiryDate.map { isoFormatter.string(from: $0) } ?? ""
            let cardFaceSourceStr = card.cardFaceSource.rawValue

            let row = "\(bank),\(type),\(endNum),\(c1),\(c2),\(region),\(defRate),\(forRate),\(locCap),\(forCap),\(diningRate),\(groceryRate),\(travelRate),\(digitalRate),\(otherRate),\(diningCap),\(groceryCap),\(travelCap),\(digitalCap),\(otherCap),\(capPeriodStr),\(rDay),\(quoteField(pmRatesStr)),\(quoteField(pmCapsStr)),\(rewardTypeStr),\(pointName),\(pointBank),\(pointValue),\(pointCurrency),\(cardKindStr),\(cardNetworkStr),\(statementDayStr),\(annualFeeStr),\(quoteField(annualFeeWaiverStr)),\(quoteField(tagsStr)),\(quoteField(notesStr)),\(balanceStr),\(benefitExpiryStr),\(cardExpiryStr),\(cardFaceSourceStr)\n"
            csvString.append(row)
        }
        return csvString
    }

    // MARK: - Export Points
    static func generatePointsCSV(from points: [Point]) -> String {
        var csvString = "\u{FEFF}" + pointsHeader + "\n"

        for point in points {
            let bank = point.bankName.replacingOccurrences(of: ",", with: "，")
            let name = point.pointName.replacingOccurrences(of: ",", with: "，")
            let value = String(format: "%.6f", point.pointValue)
            let currency = point.valueCurrencyCode.currencyCode

            csvString.append("\(bank),\(name),\(value),\(currency)\n")
        }
        return csvString
    }

    // MARK: - Import Cards (RFC 4180 compliant parsing)
    static func parseCSV(content: String, into context: ModelContext) throws {
        let rows = parseCSVRows(content)
        guard !rows.isEmpty else { return }

        // Build column map from header
        let colMap = buildColumnMap(from: rows[0])

        let templates = try context.fetch(FetchDescriptor<CardTemplate>())
        let templateMap = Dictionary(uniqueKeysWithValues: templates.map { ($0.templateKey, $0) })
        let points = try context.fetch(FetchDescriptor<Point>())
        var pointMap: [String: Point] = Dictionary(uniqueKeysWithValues: points.map { (pointKey(for: $0), $0) })

        for (index, columns) in rows.enumerated() {
            if index == 0 { continue } // skip header
            if columns.isEmpty || (columns.count == 1 && columns[0].trimmingCharacters(in: .whitespaces).isEmpty) { continue }
            if columns.count < 23 { continue }

            let bankName = columns[0]
            let type = columns[1]
            let endNum = columns[2]
            let c1 = columns[3]
            let c2 = columns[4]
            let regionRaw = columns[5]
            let region = Region.allCases.first(where: { $0.rawValue == regionRaw }) ?? .cn

            let defRate = (Double(columns[6]) ?? 0) / 100.0
            let forRateStr = columns[7]
            let forRate = forRateStr.isEmpty ? nil : (Double(forRateStr) ?? 0) / 100.0
            let locCap = Double(columns[8]) ?? 0
            let forCap = Double(columns[9]) ?? 0

            // Use column map for category rates/caps (handles anime column presence)
            var specialRates: [Category: Double] = [:]
            var categoryCaps: [Category: Double] = [:]

            let rateColumns: [(Category, String)] = [
                (.dining, "餐饮加成(%)"), (.grocery, "超市加成(%)"), (.travel, "出行加成(%)"),
                (.digital, "数码加成(%)"), (.other, "其他加成(%)")
            ]
            let capColumns: [(Category, String)] = [
                (.dining, "餐饮上限"), (.grocery, "超市上限"), (.travel, "出行上限"),
                (.digital, "数码上限"), (.other, "其他上限")
            ]

            for (cat, colName) in rateColumns {
                let val = col(columns, colMap, colName, default: "")
                if let r = Double(val), r > 0 { specialRates[cat] = r / 100.0 }
            }
            for (cat, colName) in capColumns {
                let val = col(columns, colMap, colName, default: "")
                if let c = Double(val), c > 0 { categoryCaps[cat] = c }
            }

            // 兼容旧 CSV：将二次元列合并到 .other
            let animeRateVal = col(columns, colMap, "二次元加成(%)", default: "")
            if let r = Double(animeRateVal), r > 0 {
                let existing = specialRates[.other] ?? 0
                specialRates[.other] = max(existing, r / 100.0)
            }
            let animeCapVal = col(columns, colMap, "二次元上限", default: "")
            if let c = Double(animeCapVal), c > 0 {
                let existing = categoryCaps[.other] ?? 0
                categoryCaps[.other] = max(existing, c)
            }

            let capPeriod: CapPeriod
            let capStr = col(columns, colMap, "上限周期(monthly/yearly)", default: "yearly").lowercased()
            switch capStr {
            case "monthly", "month", "m", "按月": capPeriod = .monthly
            default: capPeriod = .yearly
            }

            let rDay = Int(col(columns, colMap, "还款日", default: "0")) ?? 0

            let pmRates = parseDictionaryString(col(columns, colMap, "支付方式加成(代码:rate)", default: ""), isRate: true)
            let pmCaps = parseDictionaryString(col(columns, colMap, "支付方式上限(代码:cap)", default: ""), isRate: false)

            var rewardType: RewardType = .cashback
            let rewardRaw = col(columns, colMap, "奖励类型", default: "").lowercased()
            if rewardRaw == RewardType.points.rawValue || rewardRaw == "积分" {
                rewardType = .points
            }

            var pointProgram: Point? = nil
            let pName = col(columns, colMap, "积分名称", default: "")
            let pBank = col(columns, colMap, "积分银行", default: "")
            let pValueStr = col(columns, colMap, "积分价值", default: "")
            let pCurrency = col(columns, colMap, "积分币种", default: "")
            let pValue = Double(pValueStr) ?? 0

            if rewardType == .points, !pName.isEmpty, !pCurrency.isEmpty, pValue > 0 {
                let pointRegion = Self.region(from: pCurrency)
                let key = pointKey(bankName: pBank, pointName: pName, currencyCode: pointRegion.currencyCode, pointValue: pValue)
                if let existing = pointMap[key] {
                    pointProgram = existing
                } else {
                    let newPoint = Point(bankName: pBank, pointName: pName, pointValue: pValue, valueCurrencyCode: pointRegion)
                    context.insert(newPoint)
                    pointMap[key] = newPoint
                    pointProgram = newPoint
                }
            }

            // Extended fields from column map
            let cardKindStr = col(columns, colMap, "卡类型(cardKind)", default: "credit")
            let cardNetworkStr = col(columns, colMap, "卡组织", default: "")
            let statementDayVal = Int(col(columns, colMap, "账单日", default: "0")) ?? 0
            let annualFeeVal = Double(col(columns, colMap, "年费", default: "0")) ?? 0
            let annualFeeWaiverVal = col(columns, colMap, "年费减免", default: "")
            let tagsVal = col(columns, colMap, "标签", default: "[]")
            let tagsArr = (tagsVal.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
            let notesVal = col(columns, colMap, "备注", default: "")
            let benefitExpiryVal = isoFormatter.date(from: col(columns, colMap, "权益到期日", default: ""))
            let balanceVal = Double(col(columns, colMap, "余额", default: "0")) ?? 0
            let cardExpiryVal = isoFormatter.date(from: col(columns, colMap, "卡片到期日", default: ""))
            let cardFaceSourceVal = col(columns, colMap, "卡面来源", default: "gradient")

            let newCard = CreditCard(
                bankName: bankName, type: type, endNum: endNum, colorHexes: [c1, c2],
                defaultRate: defRate, specialRates: specialRates, issueRegion: region,
                foreignCurrencyRate: forRate, localBaseCap: locCap, foreignBaseCap: forCap,
                categoryCaps: categoryCaps, capPeriod: capPeriod, repaymentDay: rDay,
                paymentMethodRates: pmRates,
                paymentCaps: pmCaps,
                rewardType: rewardType,
                pointProgram: pointProgram,
                cardNetwork: cardNetworkStr,
                statementDay: statementDayVal,
                annualFee: annualFeeVal,
                annualFeeWaiver: annualFeeWaiverVal,
                tags: tagsArr,
                notes: notesVal,
                benefitExpiryDate: benefitExpiryVal,
                balance: balanceVal,
                cardExpiryDate: cardExpiryVal,
                cardKind: CardKind(rawValue: cardKindStr) ?? .credit,
                cardFaceSource: CardFaceSource(rawValue: cardFaceSourceVal) ?? .gradient
            )

            let tKey = CardTemplate.templateKey(bankName: bankName, type: type)
            newCard.templateKey = tKey

            context.insert(newCard)
            NotificationManager.shared.syncReminders(for: newCard)
        }
    }

    // MARK: - Import Points
    static func parsePointsCSV(content: String, into context: ModelContext) throws {
        let rows = parseCSVRows(content)
        guard !rows.isEmpty else { return }

        let existingPoints = try context.fetch(FetchDescriptor<Point>())
        var pointMap: [String: Point] = Dictionary(uniqueKeysWithValues: existingPoints.map { (pointKey(for: $0), $0) })

        for (index, columns) in rows.enumerated() {
            if index == 0 { continue }
            if columns.isEmpty || (columns.count == 1 && columns[0].trimmingCharacters(in: .whitespaces).isEmpty) { continue }
            if columns.count < 4 { continue }

            let bankName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let pointName = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let pointValue = Double(columns[2]) ?? 0
            let currencyCode = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !bankName.isEmpty, !pointName.isEmpty, !currencyCode.isEmpty, pointValue > 0 else { continue }

            let pointRegion = Self.region(from: currencyCode)
            let key = pointKey(
                bankName: bankName,
                pointName: pointName,
                currencyCode: pointRegion.currencyCode,
                pointValue: pointValue
            )

            if pointMap[key] == nil {
                let newPoint = Point(
                    bankName: bankName,
                    pointName: pointName,
                    pointValue: pointValue,
                    valueCurrencyCode: pointRegion
                )
                context.insert(newPoint)
                pointMap[key] = newPoint
            }
        }
    }

    // MARK: - Detect CSV type from header
    enum CSVType {
        case cards
        case points
        case unknown
    }

    static func detectCSVType(content: String) -> CSVType {
        let rows = parseCSVRows(content)
        guard let firstRow = rows.first, !firstRow.isEmpty else { return .unknown }

        let headerLine = firstRow.joined(separator: ",")

        // Check for points header
        if headerLine.contains("积分名称") && headerLine.contains("积分价值") && headerLine.contains("币种代码") && !headerLine.contains("尾号") {
            return .points
        }

        // Check for cards header
        if headerLine.contains("尾号") && headerLine.contains("颜色1") && headerLine.contains("本币返现率") {
            return .cards
        }

        return .unknown
    }

    // MARK: - RFC 4180 CSV Row Parser (handles quoted fields with embedded newlines/commas)

    private static func parseCSVRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentFields: [String] = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(content)

        var i = 0
        while i < chars.count {
            let ch = chars[i]

            if inQuotes {
                if ch == "\"" {
                    // Check for escaped quote ""
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(ch)
                    i += 1
                    continue
                }
            }

            // Not in quotes
            if ch == "\"" {
                inQuotes = true
                i += 1
                continue
            } else if ch == "," {
                currentFields.append(currentField)
                currentField = ""
                i += 1
                continue
            } else if ch == "\r" {
                // CR or CRLF: end of row
                currentFields.append(currentField)
                currentField = ""
                rows.append(currentFields)
                currentFields = []
                if i + 1 < chars.count && chars[i + 1] == "\n" {
                    i += 2 // skip CRLF
                } else {
                    i += 1
                }
                continue
            } else if ch == "\n" {
                currentFields.append(currentField)
                currentField = ""
                rows.append(currentFields)
                currentFields = []
                i += 1
                continue
            } else {
                currentField.append(ch)
                i += 1
                continue
            }
        }

        // Handle last field/row (file may not end with newline)
        if !currentField.isEmpty || !currentFields.isEmpty {
            currentFields.append(currentField)
            rows.append(currentFields)
        }

        return rows
    }

    // MARK: - Helper Functions

    private static func buildColumnMap(from header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, col) in header.enumerated() {
            let key = col.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}")).trimmingCharacters(in: .whitespaces)
            map[key] = i
        }
        return map
    }

    private static func col(_ columns: [String], _ colMap: [String: Int], _ name: String, default defaultValue: String) -> String {
        guard let idx = colMap[name], idx < columns.count else { return defaultValue }
        return columns[idx]
    }

    private static func fmtRate(_ val: Double?) -> String {
        guard let v = val else { return "" }
        return String(format: "%.2f", v * 100)
    }

    private static func fmtCap(_ val: Double?) -> String {
        guard let v = val, v > 0 else { return "" }
        return String(format: "%.0f", v)
    }

    private static func quoteField(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") else { return s }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func parseDictionaryString(_ str: String, isRate: Bool) -> [PaymentMethod: Double] {
        var result: [PaymentMethod: Double] = [:]
        let items = str.components(separatedBy: "|")
        for item in items {
            let parts = item.components(separatedBy: ":")
            if parts.count == 2 {
                let keyStr = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let valStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

                if let key = PaymentMethod(rawValue: keyStr), let val = Double(valStr) {
                    result[key] = isRate ? (val / 100.0) : val
                }
            }
        }
        return result
    }

    private static func pointKey(
        bankName: String,
        pointName: String,
        currencyCode: String,
        pointValue: Double
    ) -> String {
        let valueKey = String(format: "%.8f", pointValue)
        return "\(bankName)|\(pointName)|\(currencyCode)|\(valueKey)"
    }

    private static func pointKey(for point: Point) -> String {
        pointKey(
            bankName: point.bankName,
            pointName: point.pointName,
            currencyCode: point.valueCurrencyCode.currencyCode,
            pointValue: point.pointValue
        )
    }

    private static func region(from currencyCode: String) -> Region {
        let normalized = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let match = Region.allCases.first(where: { $0.currencyCode.uppercased() == normalized }) {
            return match
        }
        return .other
    }
}

// MARK: - Array Extensions for Export

extension Array where Element == CreditCard {
    func exportCSVFile() -> URL? {
        let csvString = CardCSVHelper.generateCSV(from: self)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let fileName = "Cards_Backup_\(dateString).csv"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("卡片导出失败: \(error)")
            return nil
        }
    }
}

extension Array where Element == Point {
    func exportPointsCSVFile() -> URL? {
        let csvString = CardCSVHelper.generatePointsCSV(from: self)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let fileName = "Points_Backup_\(dateString).csv"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("积分导出失败: \(error)")
            return nil
        }
    }
}
