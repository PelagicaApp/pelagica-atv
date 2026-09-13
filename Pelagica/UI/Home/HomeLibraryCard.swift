//
//  HomeLibraryCard.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct HomeLibraryCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: TabNavigationCoordinator
    let library: BaseItemDto

    private let cornerRadius: CGFloat = 12
    private let aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                navigationCoordinator.openLibrary(library)
            } label: {
                ZStack {
                    Color.white.opacity(0.06)

                    AsyncImage(url: imageURL) { phase in
                        ZStack {
                            SkeletonView()
                                .opacity(phase.image == nil && !isFailure(phase) ? 1 : 0)
                            fallbackIcon
                                .opacity(isFailure(phase) ? 1 : 0)
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            }
                        }
                    }
                    .animation(nil, value: imageURL)
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)

            Text(library.name ?? "Library")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "books.vertical")
            .font(.system(size: 32))
            .foregroundStyle(.white.opacity(0.3))
    }

    private var imageURL: URL? {
        guard let id = library.id, let client = appState.client else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(fillWidth: 600, fillHeight: 340, tag: library.imageTags?["Primary"])
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}
