//
//  PelagicaPicker.swift
//  Pelagica
//

import SwiftUI

struct PelagicaPickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    /// Shown before the label
    var leading: String?

    var id: Value { value }
}

struct PelagicaPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [PelagicaPickerOption<Value>]

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 16) {
                if let leading = selectedOption?.leading {
                    Text(leading)
                }
                Text(selectedOption?.label ?? "")
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
        .fullScreenCover(isPresented: $isPresented) {
            PelagicaPickerList(title: title, selection: $selection, options: options)
        }
    }

    private var selectedOption: PelagicaPickerOption<Value>? {
        options.first { $0.value == selection }
    }
}

private struct PelagicaPickerList<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [PelagicaPickerOption<Value>]

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedValue: Value?

    var body: some View {
        ZStack {
            PelagicaBackground()

            VStack(alignment: .leading, spacing: 32) {
                Text(title)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options) { option in
                            Button {
                                selection = option.value
                                dismiss()
                            } label: {
                                row(for: option)
                            }
                            .buttonStyle(PelagicaPickerRowStyle())
                            .focused($focusedValue, equals: option.value)
                        }
                    }
                    .padding(20)
                }
            }
            .frame(width: 860)
            .padding(.vertical, 80)
            .focusSection()
        }
        .defaultFocus($focusedValue, selection)
    }

    private func row(for option: PelagicaPickerOption<Value>) -> some View {
        HStack(spacing: 20) {
            if let leading = option.leading {
                Text(leading)
            }
            Text(option.label)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .opacity(option.value == selection ? 1 : 0)
        }
    }
}

private struct PelagicaPickerRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PelagicaPickerRowBody(configuration: configuration)
    }

    private struct PelagicaPickerRowBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        private let cornerRadius: CGFloat = 16

        var body: some View {
            configuration.label
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .frame(height: 76)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(isFocused ? 0.08 : 0))
                )
                .pelagicaFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
                .scaleEffect(configuration.isPressed ? 0.99 : (isFocused ? 1.02 : 1))
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}

extension String {
    var flagEmoji: String? {
        let scalars = uppercased().unicodeScalars
        guard scalars.count == 2, scalars.allSatisfy({ ("A"..."Z").contains($0) }) else { return nil }
        return String(String.UnicodeScalarView(scalars.compactMap { UnicodeScalar(127397 + $0.value) }))
    }
}
