//
//  ItemCard.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.displayScale) private var displayScale
    let item: BaseItemDto
    var detailText: (BaseItemDto) -> String = { item in
        item.premiereDate.map { String(Calendar.current.component(.year, from: $0)) } ?? ""
    }
    var useThumb: Bool = false
    /// Streamystats similarity score (0–1)
    var similarity: Double?

    private let cornerRadius: CGFloat = 16
    private var posterAspectRatio: CGFloat { useThumb ? 16.0 / 9.0 : 2.0 / 3.0 }

    @State private var measuredWidth: CGFloat?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            NavigationLink(value: ItemDetailRoute(item: item)) {
                GeometryReader { proxy in
                    posterBody(size: proxy.size)
                        .onAppear { updateMeasuredWidth(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, newValue in
                            updateMeasuredWidth(newValue)
                        }
                }
                .aspectRatio(posterAspectRatio, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    if let similarity { similarityBadge(similarity) }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(item.name ?? i18n.t("no_title"))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(detailText(item))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private func posterBody(size: CGSize) -> some View {
        ZStack {
            Color.white.opacity(0.06)
            
            AsyncImage(url: imageURL) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && !isFailure(phase) ? 1 : 0)
                    fallbackIcon
                        .opacity(isFailure(phase) ? 1 : 0)
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    }
                }
            }
            .animation(nil, value: measuredWidth)
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func similarityBadge(_ similarity: Double) -> some View {
        let color: Color = similarity >= 0.6 ? .green : similarity >= 0.3 ? .yellow : .red
        return HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
            Text("\(Int((similarity * 100).rounded()))%")
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.7), in: Capsule())
        .padding(12)
        .contentTransition(.identity)
        .transaction { $0.animation = nil }
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        if let measuredWidth, abs(measuredWidth - width) < 1 { return }
        measuredWidth = width
    }
    
    private var fallbackIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 32))
            .foregroundStyle(.white.opacity(0.3))
    }
    
    private var imageURL: URL? {
        guard let id = item.id, let client = appState.client, let measuredWidth else { return nil }
        
        let pixelWidth = Int((measuredWidth * displayScale).rounded())
        let pixelHeight = Int((measuredWidth * displayScale / posterAspectRatio).rounded())

        let imageType: ImageType
        let tag: String?
        if useThumb, let thumbTag = item.imageTags?["Thumb"] {
            imageType = .thumb
            tag = thumbTag
        } else if useThumb, let backdropTag = item.backdropImageTags?.first {
            imageType = .backdrop
            tag = backdropTag
        } else {
            imageType = .primary
            tag = item.imageTags?["Primary"]
        }

        let request = Paths.getItemImage(
            itemID: id,
            imageType: imageType.rawValue,
            parameters: .init(
                fillWidth: pixelWidth,
                fillHeight: pixelHeight,
                tag: tag
            )
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}
