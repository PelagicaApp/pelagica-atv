//
//  StudiosView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct StudiosView: View {
    @EnvironmentObject private var appState: AppState

    @State private var studios: [StudioEntry]?

    private let columns = [GridItem(.adaptive(minimum: 420), spacing: 40)]

    var body: some View {
        ZStack {
            PelagicaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(i18n.t("studios"))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)

                    LazyVGrid(columns: columns, spacing: 60) {
                        if let studios {
                            ForEach(studios) { studio in
                                HomeStudioCard(studio: studio)
                            }
                        } else {
                            ForEach(0..<12, id: \.self) { _ in
                                SkeletonView()
                                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .focusSection()

                    if studios?.isEmpty == true {
                        Text(i18n.t("library:no_items_description"))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(60)
            }
        }
        .task {
            guard studios == nil, let client = appState.client, let userID = appState.currentUser?.id else { return }
            studios = await StudiosAPI.fetchStudiosByItemCount(client: client, userID: userID)
        }
    }
}
