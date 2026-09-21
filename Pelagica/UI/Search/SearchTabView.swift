//
//  SearchTabView.swift
//  Pelagica
//

import SwiftUI
import JellyfinAPI
import Get

struct SearchTabView: View {
    @EnvironmentObject private var appState: AppState
    
    @Namespace private var namespace
    @FocusState private var isGridFocused: Bool
    
    @State private var results: [BaseItemDto] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var path = NavigationPath()
    @State private var query = ""

    let resultsCount = 25

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        } else if isLoading && results.isEmpty {
                            LazyVGrid(columns: columns, spacing: 60) {
                                ForEach(0..<10, id: \.self) { _ in
                                    SkeletonView()
                                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            .focusSection()
                        } else if results.isEmpty {
                            emptyState
                                .focusSection()
                        } else {
                            LazyVGrid(columns: columns, spacing: 60) {
                                ForEach(results.indices, id: \.self) { index in
                                    ItemCard(item: results[index])
                                        .prefersDefaultFocus(index == 0, in: namespace)
                                }
                            }
                            .focusScope(namespace)
                            .focusSection()
                        }
                    }
                    .padding(60)
                }
            }
            .navigationDestination(for: ItemDetailRoute.self) { route in
                ItemDestinationView(item: route.item)
            }
            .searchable(text: $query, prompt: "Search")
        }
        .onDisappear { path = NavigationPath() }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            results = []
            errorMessage = nil
            isLoading = true
            await search()
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No results found")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("Try adjusting your search or filter to find what you're looking for.")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private func search() async {
        guard let client = appState.client else { return }
        do {
            let result = try await client.sendItems(Paths.getItems(parameters: .init(
                userID: appState.currentUser?.id,
                limit: resultsCount,
                isRecursive: true,
                searchTerm: query,
                fields: [.overview, .parentID],
                enableUserData: true,
            ))).value
            guard !Task.isCancelled else { return }
            results = result.items ?? []
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Couldn't load items."
        }
    }
}

#Preview {
    SearchTabView()
}
