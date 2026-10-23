//
//  ContinueWatchingCard.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ContinueWatchingCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.displayScale) private var displayScale
    let item: BaseItemDto
    let titleText: String
    let detailText: String
    var useSeriesImage = false

    private let cornerRadius: CGFloat = 12
    private let aspectRatio: CGFloat = 16.0 / 9.0

    @State private var measuredWidth: CGFloat?
    @State private var playbackTarget: PlaybackTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: startPlayback) {
                GeometryReader { proxy in
                    thumbBody(size: proxy.size)
                        .onAppear { updateMeasuredWidth(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, newValue in
                            updateMeasuredWidth(newValue)
                        }
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)

            VStack(alignment: .leading, spacing: 8) {
                Text(titleText)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .fullScreenCover(item: $playbackTarget) { target in
            VideoPlayerView(item: target.item, startTicks: target.startTicks)
                .ignoresSafeArea()
        }
    }

    private func startPlayback() {
        guard item.id != nil else { return }
        let startTicks = item.userData?.playbackPositionTicks ?? 0
        playbackTarget = PlaybackTarget(item: item, startTicks: startTicks)
    }

    @ViewBuilder
    private func thumbBody(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            Color.white.opacity(0.06)

            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    SkeletonView()
                }
            }
            .animation(nil, value: measuredWidth)

            if let progress {
                GeometryReader { barProxy in
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.4)
                        Color.white.frame(width: barProxy.size.width * progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var progress: CGFloat? {
        guard
            let runtime = item.runTimeTicks, runtime > 0,
            let position = item.userData?.playbackPositionTicks
        else { return nil }
        return min(max(CGFloat(position) / CGFloat(runtime), 0), 1)
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        if let measuredWidth, abs(measuredWidth - width) < 1 { return }
        measuredWidth = width
    }

    private var imageURL: URL? {
        guard let client = appState.client, let measuredWidth else { return nil }

        let pixelWidth = Int((measuredWidth * displayScale).rounded())
        let pixelHeight = Int((measuredWidth * displayScale / aspectRatio).rounded())

        guard let source = (useSeriesImage ? seriesImageSource : nil) ?? itemImageSource else { return nil }

        let request = Paths.getItemImage(
            itemID: source.itemID,
            imageType: source.imageType.rawValue,
            parameters: .init(fillWidth: pixelWidth, fillHeight: pixelHeight, tag: source.tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private var itemImageSource: (itemID: String, imageType: ImageType, tag: String?)? {
        guard let id = item.id else { return nil }
        if let thumbTag = item.imageTags?["Thumb"] {
            return (id, .thumb, thumbTag)
        } else if let backdropTag = item.backdropImageTags?.first {
            return (id, .backdrop, backdropTag)
        } else {
            return (id, .primary, item.imageTags?["Primary"])
        }
    }

    /// Series thumb or backdrop for episodes, nil when the item has none
    private var seriesImageSource: (itemID: String, imageType: ImageType, tag: String?)? {
        guard item.type == .episode else { return nil }
        if let seriesID = item.seriesID, let thumbTag = item.seriesThumbImageTag {
            return (seriesID, .thumb, thumbTag)
        } else if let thumbItemID = item.parentThumbItemID, let thumbTag = item.parentThumbImageTag {
            return (thumbItemID, .thumb, thumbTag)
        } else if let backdropItemID = item.parentBackdropItemID, let backdropTag = item.parentBackdropImageTags?.first {
            return (backdropItemID, .backdrop, backdropTag)
        }
        return nil
    }
}
