//
//  PelagicaStyle.swift
//  Pelagica
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PelagicaHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            PelagicaIcon(size: 64)
            Text("Pelagica")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

struct PelagicaBackground: View {
    var body: some View {
//        LinearGradient(
//            colors: [
//                Color(white: 0.08),
//                .black,
//            ],
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .ignoresSafeArea()
        Color.black.ignoresSafeArea()
    }
}

struct PelagicaScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            PelagicaBackground()

            VStack(spacing: 40) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 110)
        }
    }
}

extension View {
    func pelagicaFocusRing(isFocused: Bool, cornerRadius: CGFloat, offset: CGFloat = 7) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius + offset)
                .stroke(Color.white.opacity(0.6), lineWidth: 4.5)
                .padding(-offset)
                .opacity(isFocused ? 1 : 0)
        )
        .animation(.easeOut(duration: 0.14), value: isFocused)
    }
}

enum PelagicaButtonEmphasis {
    /// The main action on a screen: light fill, dark text.
    case primary
    /// An alternate action: dark fill with a thin border, light text.
    case secondary
    /// A tertiary link with no fill at all.
    case plain
}

struct PelagicaButtonStyle: ButtonStyle {
    var emphasis: PelagicaButtonEmphasis = .primary

    func makeBody(configuration: Configuration) -> some View {
        PelagicaButtonBody(configuration: configuration, emphasis: emphasis)
    }

    private struct PelagicaButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let emphasis: PelagicaButtonEmphasis
        @Environment(\.isFocused) private var isFocused
        @Environment(\.isEnabled) private var isEnabled

        private let cornerRadius: CGFloat = 16

        var body: some View {
            configuration.label
                .font(.system(size: 28, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(foreground)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)
                .frame(height: emphasis == .plain ? nil : 76)
                .padding(.vertical, emphasis == .plain ? 16 : 0)
                .background {
                    if emphasis != .plain {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(fill)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .strokeBorder(Color.white.opacity(emphasis == .secondary ? 0.35 : 0), lineWidth: 1.5)
                            )
                    }
                }
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.03 : 1))
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }

        private var foreground: Color {
            guard isEnabled else { return .white.opacity(0.3) }
            switch emphasis {
                case .primary: return .black
                case .secondary, .plain: return .white
            }
        }

        private var fill: Color {
            guard isEnabled else { return .white.opacity(0.05) }
            switch emphasis {
                case .primary: return Color(white: 0.9)
                case .secondary: return .white.opacity(0.08)
                case .plain: return .clear
            }
        }
    }
}

struct PelagicaCircleButtonStyle: ButtonStyle {
    var diameter: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        PelagicaCircleButtonBody(configuration: configuration, diameter: diameter)
    }

    private struct PelagicaCircleButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let diameter: CGFloat
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: diameter / 2)
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.03 : 1))
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}

struct PelagicaToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 24) {
                configuration.label
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                PelagicaSwitch(isOn: configuration.isOn)
            }
        }
        .buttonStyle(PelagicaToggleButtonStyle())
    }

    private struct PelagicaToggleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            PelagicaToggleButtonBody(configuration: configuration)
        }
    }

    private struct PelagicaToggleButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        private let cornerRadius: CGFloat = 16

        var body: some View {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(isFocused ? 0.08 : 0))
                )
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }

    private struct PelagicaSwitch: View {
        let isOn: Bool
        @Environment(\.isEnabled) private var isEnabled

        private let width: CGFloat = 88
        private let height: CGFloat = 48
        private let knobInset: CGFloat = 5

        var body: some View {
            Capsule()
                .fill(isOn ? Color(white: 0.9) : .white.opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isOn ? 0 : 0.35), lineWidth: 1.5)
                )
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Color.black : Color.white.opacity(0.7))
                        .padding(knobInset)
                }
                .frame(width: width, height: height)
                .opacity(isEnabled ? 1 : 0.3)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
        }
    }
}

struct PelagicaField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure = false
    var label = ""
    #if canImport(UIKit)
    var contentType: UITextContentType?
    #endif
    var onCommit: () -> Void = {}

    @FocusState private var isFocused: Bool
    private let cornerRadius: CGFloat = 16

    var body: some View {
        ZStack(alignment: .leading) {
            Color.white.opacity(0.08)

            visibleText
                .font(.system(size: 28))
                .lineLimit(1)
                .padding(.horizontal, 24)

            realField
                .foregroundStyle(.clear)
                .tint(.clear)
                .compositingGroup()
                .opacity(0.02) // It needs to be at least 0.02 to be focusable
                .padding(.horizontal, 24)
        }
        .frame(height: 76)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
        )
        .pelagicaFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
    }

    @ViewBuilder
    private var visibleText: some View {
        if text.isEmpty {
            Text(placeholder)
                .foregroundStyle(Color.white.opacity(0.35))
        } else {
            Text(isSecure ? String(repeating: "•", count: text.count) : text)
                .foregroundStyle(Color.white)
        }
    }

    @ViewBuilder
    private var realField: some View {
        if isSecure {
            SecureField(label, text: $text, onCommit: onCommit)
                .focused($isFocused)
                #if canImport(UIKit)
                .textContentType(contentType)
                #endif
        } else {
            TextField(label, text: $text, onCommit: onCommit)
                .focused($isFocused)
                .autocorrectionDisabled()
                #if canImport(UIKit)
                .textContentType(contentType)
                #endif
        }
    }
}
