//
//  ItemCards.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct PosterCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayScale) private var displayScale

    let item: BaseItemDto
    var width: CGFloat? = 120
    var detailText: String?
    var similarity: Double?

    private var scaledWidth: CGFloat? { width.map { $0 * CardMetrics.scale(sizeClass) } }

    var body: some View {
        NavigationLink(value: ItemDetailRoute(item: item)) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImage(url: imageURL)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if let similarity { SimilarityBadge(similarity: similarity) }
                    }
                    .overlay(alignment: .topTrailing) { PlayedBadge(item: item) }

                Text(item.name ?? i18n.t("no_title"))
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)

                Text(detailText ?? year)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: scaledWidth)
        }
        .buttonStyle(.plain)
    }

    private var year: String {
        item.premiereDate.map { String(Calendar.current.component(.year, from: $0)) } ?? " "
    }

    private var imageURL: URL? {
        let pixelWidth = Int(((scaledWidth ?? 270) * displayScale).rounded())
        return ItemImages.url(ItemImages.primary(item), client: appState.client, width: pixelWidth, height: pixelWidth * 3 / 2)
    }
}

struct LandscapeCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var playerPresenter: PlayerPresenter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayScale) private var displayScale

    let item: BaseItemDto
    var title: String?
    var detailText: String?
    var playsOnTap = false
    var useSeriesImage = false
    var width: CGFloat = 260
    var onTap: (() -> Void)?

    private var scaledWidth: CGFloat { width * CardMetrics.landscapeScale(sizeClass) }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { content }
            } else if playsOnTap {
                Button {
                    playerPresenter.play(item)
                } label: { content }
            } else {
                NavigationLink(value: ItemDetailRoute(item: item)) { content }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if playsOnTap {
                NavigationLink(value: ItemDetailRoute(item: item)) {
                    Label(item.seriesName ?? item.name ?? i18n.t("no_title"), systemImage: "info.circle")
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: imageURL)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    if let progress = item.playbackProgress {
                        ProgressView(value: progress)
                            .tint(.white)
                            .padding(8)
                    }
                }
                .overlay {
                    if playsOnTap || onTap != nil {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .padding(14)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title ?? item.name ?? i18n.t("no_title"))
                .font(.footnote.weight(.medium))
                .lineLimit(1)

            if let detailText, !detailText.isEmpty {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: scaledWidth)
    }

    private var imageURL: URL? {
        let pixelWidth = Int((scaledWidth * displayScale).rounded())
        let source = (useSeriesImage ? ItemImages.seriesLandscape(item) : nil) ?? ItemImages.landscape(item)
        return ItemImages.url(source, client: appState.client, width: pixelWidth, height: pixelWidth * 9 / 16)
    }
}

private struct PlayedBadge: View {
    let item: BaseItemDto

    var body: some View {
        if item.userData?.isPlayed == true {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .white)
                .font(.subheadline)
                .padding(6)
        }
    }
}

struct SimilarityBadge: View {
    let similarity: Double

    var body: some View {
        let color: Color = similarity >= 0.6 ? .green : similarity >= 0.3 ? .yellow : .red
        Text("\(Int((similarity * 100).rounded()))%")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.7), in: Capsule())
            .padding(6)
    }
}

extension BaseItemDto {
    var playbackProgress: Double? {
        guard
            let runtime = runTimeTicks, runtime > 0,
            let position = userData?.playbackPositionTicks, position > 0
        else { return nil }
        return min(max(Double(position) / Double(runtime), 0), 1)
    }
}
