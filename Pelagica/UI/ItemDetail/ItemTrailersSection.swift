//
//  ItemTrailersSection.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemTrailersSection: View {
    let trailers: [BaseItemDto]
    let onPlayTrailer: (BaseItemDto) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(i18n.t("item:trailers"))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 90)
            
            trailersRow
                .focusSection()
        }
    }
    
    private var trailersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 32) {
                ForEach(trailers, id: \.id) { trailer in
                    TrailerCard(
                        trailer: trailer,
                        onPlay: onPlayTrailer,
                    )
                }
            }
            .padding(.horizontal, 90)
        }
        .scrollClipDisabled()
    }
}

private struct TrailerCard: View {
    @EnvironmentObject private var appState: AppState
    let trailer: BaseItemDto
    var onPlay: (BaseItemDto) -> Void
    
    private let cardWidth: CGFloat = 420
    private let cornerRadius: CGFloat = 12
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                onPlay(trailer)
            } label: {
                thumbnail
            }
            .buttonStyle(.card)
            
            Text(trailer.name ?? i18n.t("item:unknown_item"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(width: cardWidth, alignment: .leading)
    }
    
    private var thumbnailHeight: CGFloat { cardWidth * 9.0 / 16.0 }
    
    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.opacity(0.06)
            
            AsyncImage(url: imageURL) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && !isFailure(phase) ? 1 : 0)
                    fallbackIcon
                        .opacity(isFailure(phase) ? 1 : 0)
                    if let image = phase.image {
                        Color.clear.overlay {
                            image.resizable().scaledToFill()
                        }
                        .clipped()
                    }
                }
            }
            
            if let durationText {
                Text(durationText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7), in: Capsule())
                    .padding(10)
            }
        }
        .frame(width: cardWidth, height: thumbnailHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    private var durationText: String? {
        guard let ticks = trailer.runTimeTicks else { return nil }
        let minutes = Int(Double(ticks) / 600_000_000)
        return "\(minutes)m"
    }
    
    private var fallbackIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.3))
    }
    
    private var imageURL: URL? {
        guard let id = trailer.id, let client = appState.client else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(width: 840, height: 473, tag: trailer.imageTags?["Primary"])
        )
        return client.url(with: request, queryAPIKey: true)
    }
    
    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}
