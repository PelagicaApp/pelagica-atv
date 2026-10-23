//
//  SeerrCards.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SeerrPosterCard: View {
    let item: SeerrMediaItem
    var width: CGFloat? = 120

    var body: some View {
        link {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImage(url: SeerrImage.poster(item.posterPath))
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        SeerrStatusBadge(status: item.status, style: .icon)
                            .padding(6)
                    }

                Text(item.title.isEmpty ? i18n.t("no_title") : item.title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)

                Text(item.releaseYear ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func link<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        if let libraryRoute = item.libraryRoute {
            NavigationLink(value: libraryRoute, label: label)
        } else {
            NavigationLink(value: item.seerrRoute, label: label)
        }
    }
}

struct SeerrStatusBadge: View {
    enum Style {
        case icon
        case label
    }

    let status: SeerrMediaStatus
    var style: Style = .label

    var body: some View {
        if style == .label || status != .unknown {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                if style == .label {
                    Text(label)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, style == .icon ? 5 : 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7), in: Capsule())
        }
    }

    private var symbol: String {
        switch status {
        case .available: "checkmark"
        case .partiallyAvailable: "circle.lefthalf.filled"
        case .processing: "arrow.down"
        case .pending: "clock"
        case .unknown: "plus"
        }
    }

    private var label: String {
        switch status {
        case .available: i18n.t("seerr:seerr_status_available")
        case .partiallyAvailable: i18n.t("seerr:seerr_status_partially_available")
        case .processing: i18n.t("seerr:seerr_status_processing")
        case .pending: i18n.t("seerr:seerr_status_pending")
        case .unknown: i18n.t("seerr:seerr_status_not_requested")
        }
    }

    private var color: Color {
        switch status {
        case .available: .green
        case .partiallyAvailable: .mint
        case .processing: .blue
        case .pending: .yellow
        case .unknown: .white
        }
    }
}
