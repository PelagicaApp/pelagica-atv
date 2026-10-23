//
//  SearchView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore

    @StateObject private var model = SearchModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] { CardMetrics.gridColumns(minimum: 104, spacing: 12, sizeClass) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let errorMessage = model.errorMessage {
                        ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
                    } else if model.isLoading && model.hasNoResults {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if model.hasNoResults && !model.query.isEmpty {
                        ContentUnavailableView(
                            i18n.t("search:no_results"),
                            systemImage: "magnifyingglass",
                            description: Text(i18n.t("search:no_results_description"))
                        )
                    } else {
                        if !model.results.isEmpty {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                                ForEach(model.results.indices, id: \.self) { index in
                                    PosterCard(item: model.results[index], width: nil)
                                }
                            }
                            .padding(.horizontal)
                        }

                        if !model.seerrResults.isEmpty {
                            Text(i18n.t("search:group_seerr"))
                                .font(.title3.weight(.bold))
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                                ForEach(model.seerrResults) { item in
                                    SeerrPosterCard(item: item, width: nil)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(i18n.t("search"))
            .searchable(text: $model.query, prompt: i18n.t("search"))
            .appDestinations()
        }
        .task(id: model.query) {
            model.bind(appState: appState, seerrStore: seerrStore)
            await model.search()
        }
    }
}
