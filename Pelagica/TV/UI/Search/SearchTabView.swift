//
//  SearchTabView.swift
//  Pelagica
//

import SwiftUI

struct SearchTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore
    
    @Namespace private var namespace
    @FocusState private var isGridFocused: Bool
    
    @StateObject private var model = SearchModel()
    @State private var path = NavigationPath()

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PelagicaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if let errorMessage = model.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        } else if model.isLoading && model.hasNoResults {
                            LazyVGrid(columns: columns, spacing: 60) {
                                ForEach(0..<10, id: \.self) { _ in
                                    SkeletonView()
                                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            .focusSection()
                        } else if model.hasNoResults {
                            emptyState
                                .focusSection()
                        } else {
                            if !model.results.isEmpty {
                                LazyVGrid(columns: columns, spacing: 60) {
                                    ForEach(model.results.indices, id: \.self) { index in
                                        ItemCard(item: model.results[index])
                                            .prefersDefaultFocus(index == 0, in: namespace)
                                    }
                                }
                                .focusScope(namespace)
                                .focusSection()
                            }

                            if !model.seerrResults.isEmpty {
                                seerrSection
                            }
                        }
                    }
                    .padding(60)
                }
            }
            .pelagicaDestinations()
            .searchable(text: $model.query, prompt: i18n.t("search"))
        }
        .onDisappear { path = NavigationPath() }
        .task(id: model.query) {
            model.bind(appState: appState, seerrStore: seerrStore)
            await model.search()
        }
    }

    private var seerrSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text(i18n.t("search:group_seerr"))
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 60) {
                ForEach(model.seerrResults) { item in
                    SeerrItemCard(item: item)
                }
            }
        }
        .padding(.top, model.results.isEmpty ? 0 : 40)
        .focusSection()
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(i18n.t("search:no_results"))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(i18n.t("search:no_results_description"))
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    SearchTabView()
        .environmentObject(SeerrStore())
}
