//
//  SeerrItemCard.swift
//  Pelagica
//

import SwiftUI

struct SeerrItemCard: View {
    let item: SeerrMediaItem

    private let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            link {
                poster
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay(alignment: .topTrailing) {
                        SeerrStatusBadge(status: item.status, style: .icon)
                            .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.title.isEmpty ? i18n.t("no_title") : item.title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.releaseYear ?? "")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func link<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        if let libraryRoute = item.libraryRoute {
            NavigationLink(value: libraryRoute, label: label)
        } else {
            NavigationLink(value: item.seerrRoute, label: label)
        }
    }

    private var poster: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white.opacity(0.06)

                AsyncImage(url: SeerrImage.poster(item.posterPath)) { phase in
                    ZStack {
                        SkeletonView()
                            .opacity(phase.image == nil && !isFailure(phase) && item.posterPath != nil ? 1 : 0)
                        Image(systemName: "film")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.3))
                            .opacity(isFailure(phase) || item.posterPath == nil ? 1 : 0)
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
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
            HStack(spacing: 8) {
                Image(systemName: symbol)
                if style == .label {
                    Text(label)
                }
            }
            .font(.system(size: style == .icon ? 18 : 22, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, style == .icon ? 8 : 14)
            .padding(.vertical, style == .icon ? 8 : 6)
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

struct SeerrItemsRow: View {
    let title: String
    let items: [SeerrMediaItem]
    var horizontalPadding: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 32) {
                    ForEach(items) { item in
                        SeerrItemCard(item: item)
                            .frame(width: 280)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}
