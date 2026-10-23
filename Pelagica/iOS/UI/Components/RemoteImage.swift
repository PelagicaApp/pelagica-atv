//
//  RemoteImage.swift
//  Pelagica
//

import SwiftUI

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var fallbackSymbol = "film"

    var body: some View {
        Color.white.opacity(0.06)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: contentMode)
                        case .failure:
                            fallback
                        default:
                            Color.white.opacity(0.04)
                        }
                    }
                } else {
                    fallback
                }
            }
            .clipped()
    }

    private var fallback: some View {
        Image(systemName: fallbackSymbol)
            .font(.title2)
            .foregroundStyle(.white.opacity(0.3))
    }
}
