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
    
    private let cornerRadius: CGFloat = 16
    private let posterAspectRatio: CGFloat = 2.0 / 3.0
    
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
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(item.name ?? "Untitled")
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
        
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(
                fillWidth: pixelWidth,
                fillHeight: pixelHeight,
                tag: item.imageTags?["Primary"]
            )
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}
