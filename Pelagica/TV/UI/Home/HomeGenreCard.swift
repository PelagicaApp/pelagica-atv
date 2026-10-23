//
//  HomeGenreCard.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeGenreCard: View {
    @EnvironmentObject private var appState: AppState
    let genre: GenreEntry

    private let cornerRadius: CGFloat = 12
    private let aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        NavigationLink(value: GenreRoute(id: genre.id, name: genre.name)) {
            ZStack(alignment: .bottomLeading) {
                Color.white.opacity(0.06)

                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().grayscale(1)
                        }
                    }
                }

                LinearGradient(
                    colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )

                genre.tint.opacity(0.35)

                Text(genre.name)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color(white: 0.8))
                    .shadow(radius: 2)
                    .lineLimit(2)
                    .padding(16)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.card)
    }

    private var imageURL: URL? {
        guard let artwork = genre.artwork, let client = appState.client else { return nil }
        let request = Paths.getItemImage(
            itemID: artwork.itemID,
            imageType: artwork.imageType.rawValue,
            parameters: .init(fillWidth: 600, fillHeight: 340, tag: artwork.tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }
}

private extension GenreEntry {
    var tint: Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        let hue = Double(hash % 360) / 360
        let saturation = 0.35 + Double((hash >> 16) % 10) / 100
        let lightness = 0.42 + Double((hash >> 32) % 8) / 100

        // HSL -> HSB
        let brightness = lightness + saturation * min(lightness, 1 - lightness)
        let hsbSaturation = brightness == 0 ? 0 : 2 * (1 - lightness / brightness)
        return Color(hue: hue, saturation: hsbSaturation, brightness: brightness)
    }
}
