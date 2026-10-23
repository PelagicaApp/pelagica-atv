//
//  HomeCards.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct LibraryCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var appState: AppState
    let library: BaseItemDto
    var width: CGFloat?

    var body: some View {
        NavigationLink(value: LibraryRoute(library: library)) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImage(
                    url: ItemImages.url(ItemImages.primary(library), client: appState.client, width: 600, height: 340),
                    fallbackSymbol: "books.vertical"
                )
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(library.name ?? i18n.t("item:unknown_library"))
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
            }
            .frame(width: width.map { $0 * CardMetrics.landscapeScale(sizeClass) })
        }
        .buttonStyle(.plain)
    }
}

struct GenreCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var appState: AppState
    let genre: GenreEntry
    var width: CGFloat? = 220

    var body: some View {
        NavigationLink(value: GenreRoute(id: genre.id, name: genre.name)) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: imageURL)
                    .grayscale(1)

                LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.4), .clear], startPoint: .bottom, endPoint: .top)
                genre.tint.opacity(0.35)

                Text(genre.name)
                    .font(.headline)
                    .foregroundStyle(Color(white: 0.85))
                    .lineLimit(2)
                    .padding(10)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(width: width.map { $0 * CardMetrics.landscapeScale(sizeClass) })
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var imageURL: URL? {
        guard let artwork = genre.artwork else { return nil }
        return ItemImages.url(
            ItemImages.Source(itemID: artwork.itemID, type: artwork.imageType, tag: artwork.tag),
            client: appState.client,
            width: 600,
            height: 340
        )
    }
}

struct StudioCard: View {
    let studio: StudioEntry
    var width: CGFloat? = 220

    @State private var logoURL: URL?
    @State private var isResolvingLogo = true
    @State private var imageFailed = false

    var body: some View {
        NavigationLink(value: StudioRoute(id: studio.id, name: studio.name)) {
            StudioCardFrame(width: width) {
                if let logoURL, !imageFailed {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().padding(24)
                        case .failure:
                            Color.clear.onAppear { imageFailed = true }
                        default:
                            EmptyView()
                        }
                    }
                } else if !isResolvingLogo {
                    StudioCardLabel(text: studio.name)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: studio.name) {
            let path = await StudioLogos.shared.logoPath(for: studio.name)
            logoURL = path.flatMap { StudioLogos.logoURL(for: $0) }
            isResolvingLogo = false
        }
    }
}

struct StudioCardFrame<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var width: CGFloat? = 220
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.white.opacity(0.06)
            content()
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(width: width.map { $0 * CardMetrics.landscapeScale(sizeClass) })
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StudioCardLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Color(white: 0.85))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 12)
    }
}
