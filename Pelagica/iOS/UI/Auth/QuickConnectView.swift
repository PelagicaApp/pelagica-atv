//
//  QuickConnectView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct QuickConnectView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    @StateObject private var model: QuickConnectModel

    init(server: DiscoveredServer) {
        _model = StateObject(wrappedValue: QuickConnectModel(server: server))
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if let code = model.code {
                Text(code)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .tracking(10)
                    .textSelection(.enabled)

                Text(i18n.t("login:quick_connect_qr_instructions", ["server": model.server.url.absoluteString]))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let url = model.quickConnectURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(model.server.name, systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }

            Spacer()
            Spacer()
        }
        .padding(24)
        .navigationTitle(i18n.t("login:sign_in_with_quick_connect"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start(appState: appState) }
        .onDisappear { model.stop() }
    }
}
