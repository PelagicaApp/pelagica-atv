//
//  SubtitleStyleSettings.swift
//  Pelagica
//

import SwiftUI

struct SubtitleStyleSettings: View {
    @EnvironmentObject private var store: SubtitleStyleStore
    
    var body: some View {
        SubtitleStylePreview(style: store.style)
        
        picker(\.textSize, title: i18n.t("settings:size")) { $0.label }
        picker(\.font, title: i18n.t("settings:subtitle_font")) { $0.label }
        picker(\.textColor, title: i18n.t("settings:subtitle_color")) { $0.label }
        picker(\.edge, title: i18n.t("settings:subtitle_edge")) { $0.label }
        picker(\.background, title: i18n.t("settings:subtitle_background")) { $0.label }
        
        Toggle(isOn: binding(\.isBold)) {
            Text(i18n.t("settings:subtitle_bold"))
        }
        
        Button {
            store.reset()
        } label: {
            Text(i18n.t("settings:subtitle_style_reset"))
        }
    }
    
    private func picker<Value: Hashable & CaseIterable>(
        _ keyPath: WritableKeyPath<SubtitleStyle, Value>,
        title: String,
        label: @escaping (Value) -> String
    ) -> some View where Value.AllCases: RandomAccessCollection {
        List {
            Picker(title, selection: binding(keyPath)) {
                ForEach(Value.allCases, id: \.self) {
                    Text(label($0)).tag($0)
                }
            }
        }
    }
    
    private func binding<Value>(_ keyPath: WritableKeyPath<SubtitleStyle, Value>) -> Binding<Value> {
        Binding(
            get: { store.style[keyPath: keyPath] },
            set: { newValue in store.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

/// An approximation of how VLC will draw the styles
private struct SubtitleStylePreview: View {
    let style: SubtitleStyle
    
    private let frameHeight: CGFloat = 240
    
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.32, blue: 0.42), Color(red: 0.55, green: 0.48, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(i18n.t("settings:subtitle_preview_text"))
                .font(.custom(style.font.familyName, size: frameHeight / CGFloat(style.textSize.relativeFontSize)))
                .fontWeight(style.isBold ? .bold : .regular)
                .foregroundStyle(Color(rgb: style.textColor.rgb))
                .modifier(SubtitleEdge(edge: style.edge))
                .padding(.horizontal, 6)
                .background(backgroundColor)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: frameHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeOut(duration: 0.15), value: style)
    }
    
    private var backgroundColor: Color {
        switch style.background {
        case .none: .clear
        case .translucent: .black.opacity(0.6)
        case .opaque: .black
        }
    }
}

private struct SubtitleEdge: ViewModifier {
    let edge: SubtitleStyle.Edge
    
    func body(content: Content) -> some View {
        switch edge {
        case .none:
            content
        case .outline:
            content
                .shadow(color: .black, radius: 0, x: 1, y: 1)
                .shadow(color: .black, radius: 0, x: -1, y: -1)
                .shadow(color: .black, radius: 0, x: 1, y: -1)
                .shadow(color: .black, radius: 0, x: -1, y: 1)
        case .dropShadow:
            content.shadow(color: .black.opacity(0.85), radius: 1, x: 0, y: 2)
        case .outlineAndShadow:
            content
                .shadow(color: .black.opacity(0.8), radius: 0.5, x: 0, y: 0)
                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1.5)
        }
    }
}

private extension Color {
    init(rgb: Int) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
