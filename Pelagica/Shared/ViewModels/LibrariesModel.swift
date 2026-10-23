//
//  LibrariesModel.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

@MainActor
final class LibrariesModel: ObservableObject {
    @Published private(set) var libraries: [BaseItemDto] = []
    @Published private(set) var errorMessage: String?

    private let supportedLibraryTypes: [CollectionType] = [.movies, .tvshows, .boxsets]

    func load(appState: AppState) async {
        guard let client = appState.client else { return }
        do {
            let result = try await client.send(Paths.getUserViews()).value
            if (result.items != nil && result.items?.isEmpty == false) {
                libraries = result.items?.filter {
                    $0.collectionType != nil && supportedLibraryTypes.contains($0.collectionType!)
                } ?? []
            } else {
                libraries = []
            }
        } catch {
            errorMessage = "Couldn't load your libraries."
        }
    }
}
