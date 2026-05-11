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
                            Text("开发者")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("项目") {
                    Link(destination: URL(string: "https://github.com/Zane-Zzx/CashbackCounter")!) {
                        Label("CardPick 仓库", systemImage: "shippingbox")
                    }
                }

                Section("致谢") {
                    Link(destination: URL(string: "https://github.com/raytracingon/cashbackcounter")!) {
                        Label("CashbackCounter 原项目", systemImage: "shippingbox")
                    }
                    Link(destination: URL(string: "https://github.com/HarukaKinen/Cardentify")!) {
                        Label("调用卡面库 Cardentify", systemImage: "shippingbox")
                    }
                    Link(destination: URL(string: "https://github.com/fawazahmed0/exchange-api")!) {
                        Label("调用货币费率数据库 exchange-api", systemImage: "shippingbox")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
