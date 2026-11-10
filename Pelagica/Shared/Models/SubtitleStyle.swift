//
//  SubtitleStyle.swift
//  Pelagica
//

import Foundation

struct SubtitleStyle: Codable, Hashable {
    enum TextSize: String, Codable, CaseIterable {
        case smaller, small, normal, large, larger, extraLarge
    }

    enum Font: String, Codable, CaseIterable {
        case standard, rounded, serif, typewriter, monospace
    }

    enum TextColor: String, Codable, CaseIterable {
        case white, yellow, cyan, green, gray
    }

    enum Edge: String, Codable, CaseIterable {
        case none, outline, dropShadow, outlineAndShadow
    }

    enum Background: String, Codable, CaseIterable {
        case none, translucent, opaque
    }

    var textSize: TextSize = .normal
    var font: Font = .standard
    var isBold = true
    var textColor: TextColor = .white
    var edge: Edge = .outlineAndShadow
    var background: Background = .none

    static let `default` = SubtitleStyle()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textSize = (try? container.decode(TextSize.self, forKey: .textSize)) ?? .normal
        font = (try? container.decode(Font.self, forKey: .font)) ?? .standard
        isBold = (try? container.decode(Bool.self, forKey: .isBold)) ?? true
        textColor = (try? container.decode(TextColor.self, forKey: .textColor)) ?? .white
        edge = (try? container.decode(Edge.self, forKey: .edge)) ?? .outlineAndShadow
        background = (try? container.decode(Background.self, forKey: .background)) ?? .none
    }

    // MARK: - VLC

    var vlcOptions: [String] {
        var options = [
            "--freetype-font=\(font.familyName)",
            "--freetype-rel-fontsize=\(textSize.relativeFontSize)",
            "--freetype-color=\(textColor.rgb)",
            "--freetype-outline-color=0",
            "--freetype-shadow-color=0",
            "--freetype-shadow-angle=-90",
            "--freetype-background-color=0",
        ]
        if isBold {
            options.append("--freetype-bold")
        }

        switch edge {
        case .none:
            options += ["--freetype-outline-thickness=0", "--freetype-shadow-opacity=0"]
        case .outline:
            options += ["--freetype-outline-thickness=4", "--freetype-outline-opacity=255", "--freetype-shadow-opacity=0"]
        case .dropShadow:
            options += ["--freetype-outline-thickness=0", "--freetype-shadow-opacity=220", "--freetype-shadow-distance=0.06"]
        case .outlineAndShadow:
            options += [
                "--freetype-outline-thickness=2", "--freetype-outline-opacity=200",
                "--freetype-shadow-opacity=160", "--freetype-shadow-distance=0.04",
            ]
        }

        switch background {
        case .none: options.append("--freetype-background-opacity=0")
        case .translucent: options.append("--freetype-background-opacity=150")
        case .opaque: options.append("--freetype-background-opacity=255")
        }
        return options
    }
}

extension SubtitleStyle.TextSize {
    var relativeFontSize: Int {
        switch self {
        case .smaller: 22
        case .small: 19
        case .normal: 16
        case .large: 13
        case .larger: 11
        case .extraLarge: 9
        }
    }

    var label: String {
        switch self {
        case .smaller: i18n.t("settings:subtitle_size_smaller")
        case .small: i18n.t("settings:small")
        case .normal: i18n.t("settings:medium")
        case .large: i18n.t("settings:large")
        case .larger: i18n.t("settings:subtitle_size_larger")
        case .extraLarge: i18n.t("settings:xlarge")
        }
    }
}

extension SubtitleStyle.Font {
    var familyName: String {
        switch self {
        case .standard: "Helvetica Neue"
        case .rounded: "Avenir Next"
        case .serif: "Georgia"
        case .typewriter: "American Typewriter"
        case .monospace: "Menlo"
        }
    }

    var label: String {
        switch self {
        case .standard: i18n.t("item:default")
        case .rounded: i18n.t("settings:subtitle_font_rounded")
        case .serif: i18n.t("settings:subtitle_font_serif")
        case .typewriter: i18n.t("settings:subtitle_font_typewriter")
        case .monospace: i18n.t("settings:subtitle_font_monospace")
        }
    }
}

extension SubtitleStyle.TextColor {
    var rgb: Int {
        switch self {
        case .white: 0xFFFFFF
        case .yellow: 0xFFEB3B
        case .cyan: 0x4DD0E1
        case .green: 0x9CCC65
        case .gray: 0xBDBDBD
        }
    }

    var label: String {
        switch self {
        case .white: i18n.t("settings:subtitle_color_white")
        case .yellow: i18n.t("settings:subtitle_color_yellow")
        case .cyan: i18n.t("settings:subtitle_color_cyan")
        case .green: i18n.t("settings:subtitle_color_green")
        case .gray: i18n.t("settings:subtitle_color_gray")
        }
    }
}

extension SubtitleStyle.Edge {
    var label: String {
        switch self {
        case .none: i18n.t("settings:subtitle_edge_none")
        case .outline: i18n.t("settings:subtitle_edge_outline")
        case .dropShadow: i18n.t("settings:subtitle_edge_drop_shadow")
        case .outlineAndShadow: i18n.t("settings:subtitle_edge_outline_shadow")
        }
    }
}

extension SubtitleStyle.Background {
    var label: String {
        switch self {
        case .none: i18n.t("settings:subtitle_background_none")
        case .translucent: i18n.t("settings:subtitle_background_translucent")
        case .opaque: i18n.t("settings:subtitle_background_opaque")
        }
    }
}
