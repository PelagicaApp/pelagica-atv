//
//  LibrariesView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct LibrariesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var model = LibrariesModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] { CardMetrics.gridColumns(minimum: 160, spacing: 16, sizeClass) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage = model.errorMessage {
                    ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(model.libraries, id: \.id) { library in
                            LibraryCard(library: library)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(i18n.t("library:title"))
            .appDestinations()
        }
        .task { await model.load(appState: appState) }
    }
}
