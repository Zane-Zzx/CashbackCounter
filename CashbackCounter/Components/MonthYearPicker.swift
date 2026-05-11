import SwiftUI

struct MonthYearPicker: View {
    @Binding var date: Date
    @Binding var isWholeYear: Bool
    @Environment(\.dismiss) var dismiss

    private let years: [Int] = Array((Calendar.current.component(.year, from: Date()) - 10)...(Calendar.current.component(.year, from: Date())))

    private let months: [Int] = Array(0...12)

    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    init(date: Binding<Date>, isWholeYear: Binding<Bool>) {
        self._date = date
        self._isWholeYear = isWholeYear

        let calendar = Calendar.current
        _selectedYear = State(initialValue: calendar.component(.year, from: date.wrappedValue))

        if isWholeYear.wrappedValue {
            _selectedMonth = State(initialValue: 0)
        } else {
            _selectedMonth = State(initialValue: calendar.component(.month, from: date.wrappedValue))
        }
    }

    var body: some View {
        VStack {
            // 顶部工具栏
            HStack {
                Button("取消") { dismiss() }
                    .foregroundColor(.secondary)
                Spacer()
                Text("选择时间").font(.headline)
                Spacer()
                Button("确定") {
                    saveSelection()
                    dismiss()
                }
                .fontWeight(.bold)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))

            // 滚轮区域
            HStack {
                // 年份
                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)年").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                // 月份 (0是全年)
                Picker("Month", selection: $selectedMonth) {
                    ForEach(months, id: \.self) { month in
                        if month == 0 {
                            Text("全年").tag(0)
                        } else {
                            Text("\(month)月").tag(month)
                        }
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .presentationDetents([.height(300)])
    }

    func saveSelection() {
        var components = DateComponents()
        components.year = selectedYear

        if selectedMonth == 0 {
            isWholeYear = true
            components.month = 1
            components.day = 1
        } else {
            isWholeYear = false
            components.month = selectedMonth
            components.day = 1
        }

        if let newDate = Calendar.current.date(from: components) {
            date = newDate
        }
    }
}
