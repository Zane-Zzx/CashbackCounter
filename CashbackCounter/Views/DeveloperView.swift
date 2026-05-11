//
//  DeveloperView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 12/3/25.
//

import SwiftUI

struct DeveloperView: View {

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Zane")
                                .font(.headline)
                            Text(String(localized: "开发者"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section(header: Text(String(localized: "项目"))) {
                    Link(destination: URL(string: "https://github.com/raytracingon/cashbackcounter")!) {
                        Label(String(localized: "CardPick 仓库"), systemImage: "shippingbox")
                    }
                }

                Section(header: Text(String(localized: "致谢"))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "基于 CashbackCounter (Junhao Huang) 开发"))
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    Link(destination: URL(string: "https://github.com/HarukaKinen/Cardentify")!) {
                        Label(String(localized: "调用卡面库 Cardentify"), systemImage: "shippingbox")
                    }
                    Link(destination: URL(string: "https://github.com/fawazahmed0/exchange-api")!) {
                        Label(String(localized: "调用货币费率数据库 exchange-api"), systemImage: "shippingbox")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
