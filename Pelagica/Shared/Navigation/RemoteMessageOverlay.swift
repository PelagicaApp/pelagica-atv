//
//  RemoteMessageOverlay.swift
//  Pelagica
//

import SwiftUI

private struct RemoteMessageOverlay: ViewModifier {
    @EnvironmentObject private var remoteControl: RemoteControlService

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = remoteControl.message {
                    VStack(spacing: 4) {
                        if let header = message.header {
                            Text(header).font(.headline)
                        }
                        if let text = message.text {
                            Text(text).font(.body)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 20)
                    .padding(.horizontal)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message.id) {
                        try? await Task.sleep(for: message.duration)
                        guard !Task.isCancelled, remoteControl.message?.id == message.id else { return }
                        remoteControl.message = nil
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: remoteControl.message)
    }
}

extension View {
    func remoteMessageOverlay() -> some View {
        modifier(RemoteMessageOverlay())
    }
}
