//
//  LibraryView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: TabNavigationCoordinator

    @State private var libraries: [BaseItemDto] = []
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var path = NavigationPath()

    private let columns = [GridItem(.adaptive(minimum: 380), spacing: 60)]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Libraries")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        } else if libraries.isEmpty {
                            Text("No libraries are available for this user.")
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
            .navigationDestination(for: ItemDetailRoute.self) { route in
                ItemDestinationView(item: route.item)
            }
        }
        .onDisappear { path = NavigationPath() }
        .task { await loadLibraries() }
        .onChange(of: navigationCoordinator.pendingLibrary) { _, pendingLibrary in
            guard let pendingLibrary else { return }
            path.append(pendingLibrary)
            navigationCoordinator.pendingLibrary = nil
        }
    }

    private func loadLibraries() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let client = appState.client, let userID = appState.currentUser?.id else {
            libraries = []
            errorMessage = "Sign in to browse your libraries."
            return
        }
        do {
            let result = try await client.sendItems(Paths.getUserViews(parameters: .init(userID: userID))).value
            libraries = (result.items ?? []).filter(LibraryPolicy.isLibrary)
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
        let imageURL = self.imageURL
        VStack(alignment: .leading, spacing: 20) {
            NavigationLink(value: library) {
                ZStack {
                    Color.white.opacity(0.06)

                    AsyncImage(url: imageURL) { phase in
                        ZStack {
                            SkeletonView()
                                .opacity(imageURL != nil && phase.image == nil && !isFailure(phase) ? 1 : 0)
                            fallbackIcon
                                .opacity(imageURL == nil || isFailure(phase) ? 1 : 0)
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            }
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
        Image(systemName: "folder")
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

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}
