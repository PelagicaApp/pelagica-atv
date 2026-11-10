//
//  QuickConnectView.swift
//  Pelagica
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct QuickConnectView: View {
    @EnvironmentObject private var appState: AppState
    let server: DiscoveredServer
    @Binding var path: NavigationPath

    @StateObject private var model: QuickConnectModel

    init(server: DiscoveredServer, path: Binding<NavigationPath>) {
        self.server = server
        _path = path
        _model = StateObject(wrappedValue: QuickConnectModel(server: server))
    }
    
    var body: some View {
        PelagicaScreen {
            PelagicaHeader()
            
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                    if let code = model.code {
                        if let quickConnectUrl = model.quickConnectURL {
                            QRCodeView(content: quickConnectUrl.absoluteString)
                                .frame(width: 250, height: 250)
                                .padding(10)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Text(code)
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .tracking(20)
                            .foregroundStyle(.white)
                        Text(i18n.t("login:quick_connect_qr_instructions", ["server": server.url.absoluteString]))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24))
                    }
                }
                Button {
                    model.stop()
                    path.removeLast()
                } label: {
                    Text(i18n.t("back"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
            }
            .frame(maxWidth: 700)
        }
        .task {
            await model.start(appState: appState)
        }
        .onAppear {
#if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
#endif
        }
        .onDisappear {
            model.stop()
#if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
#endif
        }
    }
}
