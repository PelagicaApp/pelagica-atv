//
//  LibraryView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var libraries: [BaseItemDto] = []
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 380), spacing: 60)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Libraries")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: columns, spacing: 60) {
                                ForEach(libraries, id: \.id) { library in
                                    LibraryCard(library: library)
                                }
                            }
                        }
                    }
                    .padding(60)
                }
            }
            .navigationDestination(for: BaseItemDto.self) { library in
                LibraryItemsView(library: library)
            }
        }
        .task { await loadLibraries() }
    }

    private func loadLibraries() async {
        guard let client = appState.client else { return }
        do {
            let result = try await client.send(Paths.getUserViews()).value
            libraries = result.items ?? []
        } catch {
            errorMessage = "Couldn't load your libraries."
        }
    }
}

private struct LibraryCard: View {
    @EnvironmentObject private var appState: AppState
    let library: BaseItemDto
    
    private let cornerRadius: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            NavigationLink(value: library) {
                ZStack {
                    Color.white.opacity(0.06)

                    AsyncImage(url: imageURL) { phase in
                        switch (phase) {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            fallbackIcon
                        case .empty:
                            SkeletonView()
                        @unknown default:
                            fallbackIcon
                        }
                    }
                    .animation(nil, value: imageURL)
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)
            
            Text(library.name ?? "Library")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
    
    private var fallbackIcon: some View {
        Image(systemName: "books.vertical")
            .font(.system(size: 40))
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
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}
