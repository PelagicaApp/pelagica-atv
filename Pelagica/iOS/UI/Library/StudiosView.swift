//
//  StudiosView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct StudiosView: View {
    @EnvironmentObject private var appState: AppState
    @State private var studios: [StudioEntry]?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            if let studios, studios.isEmpty {
                ContentUnavailableView(i18n.t("library:no_items_title"), systemImage: "building.2", description: Text(i18n.t("library:no_items_description")))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    if let studios {
                        ForEach(studios) { studio in
                            StudioCard(studio: studio, width: nil)
                        }
                    } else {
                        ForEach(0..<12, id: \.self) { _ in
                            StudioCardFrame(width: nil) { EmptyView() }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(i18n.t("studios"))
        .task {
            guard studios == nil, let client = appState.client, let userID = appState.currentUser?.id else { return }
            studios = await StudiosAPI.fetchStudiosByItemCount(client: client, userID: userID)
        }
    }
}
