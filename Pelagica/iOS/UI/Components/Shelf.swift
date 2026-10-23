//
//  Shelf.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct Shelf<Content: View>: View {
    let title: String
    var isLoading = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .padding(.horizontal)
                .redacted(reason: isLoading && title.isEmpty ? .placeholder : [])

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
        }
    }
}

struct SeerrShelf: View {
    let title: String
    let items: [SeerrMediaItem]

    var body: some View {
        Shelf(title: title) {
            ForEach(items) { item in
                SeerrPosterCard(item: item)
            }
        }
    }
}

/// Grey boxes standing in for a row that's still loading.
struct PlaceholderShelf: View {
    let title: String?
    var isLandscape = false

    var body: some View {
        Shelf(title: title ?? "", isLoading: true) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: isLandscape ? 260 : 120, height: isLandscape ? 146 : 180)
            }
        }
    }
}
