//
//  ItemDestinationView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct ItemDestinationView: View {
    let item: BaseItemDto

    var body: some View {
        Group {
            if LibraryPolicy.isContainer(item) {
                LibraryItemsView(library: item)
            } else if item.type == .series || LibraryPolicy.canPlayVideo(item) {
                ItemDetailView(item: item)
            } else {
                MediaInfoView(item: item)
            }
        }
        .id(item.id)
    }
}

private struct MediaInfoView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var item: BaseItemDto
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showsPhoto = false

    init(item: BaseItemDto) {
        _item = State(initialValue: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))

                Text(item.name ?? "Untitled")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)

                if item.type == .photo {
                    photo
                        .frame(height: 560)
                        .frame(maxWidth: .infinity)
                    Button("View Full Screen") { showsPhoto = true }
                        .buttonStyle(DetailActionButtonStyle(emphasis: .primary))
                }

                HStack(spacing: 24) {
                    Text(item.type?.rawValue ?? "Media")
                    if let year = item.productionYear { Text(String(year)) }
                    if let ticks = item.runTimeTicks, ticks > 0 {
                        Text("\(ticks / 600_000_000) min")
                    }
                    if let container = item.container, !container.isEmpty {
                        Text(container.uppercased())
                    }
                }
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)

                if let artists = item.artists, !artists.isEmpty {
                    Text(artists.joined(separator: ", "))
                        .font(.system(size: 26, weight: .medium))
                }
                if let album = item.album, !album.isEmpty {
                    Text(album).font(.system(size: 22))
                }
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview).font(.system(size: 22))
                }
                if item.type != .photo {
                    Text(availabilityMessage)
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                if isLoading { ProgressView() }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("Try Again") { Task { await loadMetadata() } }
                        .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(60)
            .focusSection()
        }
        .background(Color.black.ignoresSafeArea())
        .task { await loadMetadata() }
        .fullScreenCover(isPresented: $showsPhoto) {
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()
                photo
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                Button { showsPhoto = false } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(DetailActionButtonStyle(emphasis: .secondary))
                .padding(40)
            }
            .onExitCommand { showsPhoto = false }
        }
    }

    private var photo: some View {
        AsyncImage(url: imageURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else if case .failure = phase {
                Label("Couldn't load this photo.", systemImage: "photo")
                    .foregroundStyle(.secondary)
            } else if imageURL == nil {
                Label("This photo isn't available.", systemImage: "photo")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }

    private var imageURL: URL? {
        guard let id = item.id, let client = appState.client else { return nil }
        return client.url(with: Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(tag: item.imageTags?["Primary"])
        ), queryAPIKey: true)
    }

    private var availabilityMessage: String {
        switch item.type {
        case .book:
            return "Book reading and downloads aren't supported on Apple TV. Open this item in Jellyfin on another device to read or download it."
        case .audio, .audioBook:
            return "Audio playback and downloads aren't supported in this app. Open this item in a compatible Jellyfin client to listen or download it."
        case .liveTvChannel, .tvChannel:
            return "Live TV playback isn't supported by this app's current player. Open this channel in a compatible Jellyfin client."
        default:
            return "Playback and downloads for this item aren't supported in this app. Open it in a compatible Jellyfin client."
        }
    }

    private func loadMetadata() async {
        guard !isLoading else { return }
        guard let client = appState.client, let id = item.id else {
            errorMessage = "Connect to your server to load this item's details."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let full = try await client.sendItems(Paths.getItem(itemID: id, userID: appState.currentUser?.id)).value
            guard !Task.isCancelled else { return }
            item = full
        } catch is CancellationError {
        } catch {
            errorMessage = "Couldn't load all details. Please try again."
        }
    }
}
