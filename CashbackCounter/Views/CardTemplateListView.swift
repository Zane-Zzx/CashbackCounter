//
//  CardTemplateListView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

enum SheetType: Identifiable {
    case template
    case custom
    var id: Int { hashValue }
}

struct CardTemplateListView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query(sort: [
        SortDescriptor<CardTemplate>(\.bankName),
        SortDescriptor<CardTemplate>(\.type)
    ]) private var templates: [CardTemplate]

    // 1. 控制跳转的状态：存用户选了哪个模板
    @State private var selectedTemplate: CardTemplate?
    @Binding var rootSheet: SheetType?

    var body: some View {
        NavigationStack {
            List(templates) { item in
                Button(action: {
                    selectedTemplate = item
                }) {
                    HStack {
                        if let urlStr = item.pictureURL {
                            if urlStr.lowercased().hasPrefix("http"), let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .shadow(color: .black.opacity(0.1), radius: 1)

                                    case .empty:
                                        ProgressView()
                                            .frame(width: 40, height: 40)

                                    case .failure(_):
                                        gradientCircle(for: item)

                                    @unknown default:
                                        gradientCircle(for: item)
                                    }
                                }
                            }
                            else if UIImage(named: urlStr) != nil {
                                Image(urlStr)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .shadow(color: .black.opacity(0.1), radius: 1)
                            }
                            else {
                                gradientCircle(for: item)
                            }
                        } else {
                            gradientCircle(for: item)
                        }


                        VStack(alignment: .leading) {
                            Text(item.bankName).font(.headline)
                            Text(item.type).font(.caption).foregroundColor(.gray)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(Text("选择卡片模板"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                AddCardView(template: template, onSaved: {
                    rootSheet = nil
                })
            }
        }
    }

    // MARK: - 辅助视图

    private func gradientCircle(for item: CardTemplate) -> some View {
        Circle()
            .fill(LinearGradient(colors: item.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 40, height: 40)
    }
}
