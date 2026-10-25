//
//  SubtitleStyleSettings.swift
//  Pelagica
//

import SwiftUI

struct SubtitleStyleSettings: View {
    @EnvironmentObject private var store: SubtitleStyleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SubtitleStylePreview(style: store.style)

            row(i18n.t("settings:size")) {
                picker(\.textSize, title: i18n.t("settings:size")) { $0.label }
            }
            row(i18n.t("settings:subtitle_font")) {
                picker(\.font, title: i18n.t("settings:subtitle_font")) { $0.label }
            }
            row(i18n.t("settings:subtitle_color")) {
                picker(\.textColor, title: i18n.t("settings:subtitle_color")) { $0.label }
            }
            row(i18n.t("settings:subtitle_edge")) {
                picker(\.edge, title: i18n.t("settings:subtitle_edge")) { $0.label }
            }
            row(i18n.t("settings:subtitle_background")) {
                picker(\.background, title: i18n.t("settings:subtitle_background")) { $0.label }
            }

            Toggle(isOn: binding(\.isBold)) {
                Text(i18n.t("settings:subtitle_bold"))
            }
            .toggleStyle(PelagicaToggleStyle())
            .padding(.horizontal, -20)

            HStack(spacing: 15) {
                Text(i18n.t("settings:subtitle_style_description"))
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    store.reset()
                } label: {
                    Text(i18n.t("settings:subtitle_style_reset"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
                .frame(maxWidth: 250)
                .disabled(store.style == .default)
            }
        }
    }

    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 15) {
            Text(label)
                .foregroundStyle(.white)
                .font(.system(size: 28, weight: .semibold))

            Spacer()

            control()
                .frame(maxWidth: 400)
        }
    }

    private func picker<Value: Hashable & CaseIterable>(
        _ keyPath: WritableKeyPath<SubtitleStyle, Value>,
        title: String,
        label: @escaping (Value) -> String
    ) -> some View where Value.AllCases: RandomAccessCollection {
        PelagicaPicker(
            title: title,
            selection: binding(keyPath),
            options: Value.allCases.map { PelagicaPickerOption(value: $0, label: label($0)) }
        )
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
