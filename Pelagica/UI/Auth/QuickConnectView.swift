//
//  QuickConnectView.swift
//  Pelagica
//

import SwiftUI
import JellyfinAPI
import Get
#if canImport(UIKit)
import UIKit
#endif

struct QuickConnectView: View {
    @EnvironmentObject private var appState: AppState
    let server: DiscoveredServer
    @Binding var path: NavigationPath
    
    @State private var code: String?
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>?
    
    var body: some View {
        PelagicaScreen {
            PelagicaHeader()
            
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                    if let code {
                        if let quickConnectUrl = getQuickConnectUrl(code: code, server: server) {
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
                        Text("Scan this QR code and authorize or go to \(server.url) on your phone or computer, sign in, and enter this code manually.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24))
                    }
                }
                Button {
                    pollingTask?.cancel()
                    path.removeLast()
                } label: {
                    Text("Back")
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
            }
            .frame(maxWidth: 700)
        }
        .task {
            await initQuickConnect()
        }
        .onAppear {
#if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
#endif
        }
        .onDisappear {
            pollingTask?.cancel()
#if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
#endif
        }
    }
    
    private func initQuickConnect() async {
        do {
            let result = try await appState.initiateQuickConnect(server: server)
            guard let result else {
                errorMessage = "Couldn't initiate quick connect."
                return
            }
            code = result.code
            startPolling(secret: result.secret)
        } catch {
            errorMessage = "Couldn't initiate quick connect."
        }
    }
    
    private func startPolling(secret: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                
                do {
                    let isAuthenticated = try await appState.checkQuickConnectStatus(server: server, secret: secret)
                    if isAuthenticated {
                        try await appState.authenticateQuickConnect(server: server, secret: secret)
                        return
                    }
                } catch {
                    errorMessage = "Lost connection while checking status."
                    return
                }
            }
        }
    }
    
    private func getQuickConnectUrl(code: String?, server: DiscoveredServer) -> URL? {
        guard let code, !code.isEmpty else { return nil }
        
        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.path = "/web/"
        components.fragment = "/quickconnect?code=\(code)"
        
        return components.url
    }
}
