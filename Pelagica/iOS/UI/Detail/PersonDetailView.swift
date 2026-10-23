//
//  PersonDetailView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct PersonDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore

    @StateObject private var model: PersonDetailModel
    @State private var isBiographyExpanded = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] { CardMetrics.gridColumns(minimum: 104, spacing: 12, sizeClass) }

    init(route: PersonDetailRoute) {
        _model = StateObject(wrappedValue: PersonDetailModel(route: route))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 16) {
                    RemoteImage(url: model.portraitURL(width: 360, height: 540), fallbackSymbol: "person")
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.name)
                            .font(.title2.weight(.bold))
                        ForEach(model.facts, id: \.label) { fact in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(fact.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(fact.value)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                if model.hasBiography, let overview = model.person?.overview {
                    Text(overview)
                        .font(.callout)
                        .lineLimit(isBiographyExpanded ? nil : 5)
                        .onTapGesture { withAnimation { isBiographyExpanded.toggle() } }
                        .padding(.horizontal)
                }

                if model.isLoadingFilmography || !model.filmography.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(i18n.t("item:filmography"))
                            .font(.title3.weight(.bold))

                        if model.isLoadingFilmography {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                                ForEach(model.filmography, id: \.id) { item in
                                    PosterCard(item: item, width: nil)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if !model.seerrCredits.isEmpty {
                    SeerrShelf(title: i18n.t("item:known_for"), items: model.seerrCredits)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            model.bind(appState: appState, seerrStore: seerrStore)
            await model.load()
        }
    }
}
