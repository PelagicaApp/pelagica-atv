//
//  HomeHero.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeHero: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    let items: [BaseItemDto]
    let showFavoriteButton: Bool
    let showWatchlistButton: Bool

    @StateObject private var model = MediaBarModel()
    @State private var selection: String?

    private static let slideDuration: Duration = .seconds(8)

    private var currentItem: BaseItemDto? {
        items.first { $0.id == selection } ?? items.first
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(items, id: \.id) { item in
                HeroPage(item: item)
                    .tag(item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .overlay(alignment: .bottom) { controls }
        .task(id: currentItem?.id) {
            model.bind(appState: appState)
            await model.show(currentItem)
        }
        .task(id: selection) {
            guard items.count > 1, scenePhase == .active else { return }
            try? await Task.sleep(for: Self.slideDuration)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if let currentItem {
                Text(currentItem.genres?.prefix(3).joined(separator: " ⋅ ") ?? "")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    NavigationLink(value: ItemDetailRoute(item: currentItem)) {
                        Label(i18n.t("home:play"), systemImage: "play.fill")
                            .font(.headline)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)

                    if showFavoriteButton {
                        Button(action: model.toggleFavorite) {
                            Image(systemName: model.isFavorite ? "heart.fill" : "heart")
                                .frame(width: 28)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isTogglingFavorite)
                    }

                    if showWatchlistButton {
                        Button(action: model.toggleWatchlist) {
                            Image(systemName: model.isWatchlist ? "bookmark.fill" : "bookmark")
                                .frame(width: 28)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isTogglingWatchlist)
                    }
                }
                .controlSize(.large)

                if items.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(items, id: \.id) { item in
                            Circle()
                                .fill(item.id == currentItem.id ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func advance() {
        guard let index = items.firstIndex(where: { $0.id == currentItem?.id }) else { return }
        withAnimation {
            selection = items[(index + 1) % items.count].id
        }
    }
}

private struct HeroPage: View {
    @EnvironmentObject private var appState: AppState
    let item: BaseItemDto

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RemoteImage(url: ItemImages.url(ItemImages.primary(item), client: appState.client, width: 900, height: 1350))
                    .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [.black, .black.opacity(0.7), .clear, .black.opacity(0.4)],
                    startPoint: .bottom,
                    endPoint: .top
                )

                titleBlock
                    .padding(.horizontal, 24)
                    .padding(.bottom, 130)
            }
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        if let logoURL = ItemImages.url(ItemImages.logo(item), client: appState.client, width: 600) {
            AsyncImage(url: logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    title
                }
            }
            .frame(maxWidth: 260, maxHeight: 90)
        } else {
            title
        }
    }

    private var title: some View {
        Text(item.name ?? "")
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
}
