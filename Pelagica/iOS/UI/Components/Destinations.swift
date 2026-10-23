//
//  Destinations.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

extension View {
    func appDestinations() -> some View {
        self
            .navigationDestination(for: ItemDetailRoute.self) { route in
                ItemDetailView(item: route.item)
            }
            .navigationDestination(for: PersonDetailRoute.self) { route in
                PersonDetailView(route: route)
            }
            .navigationDestination(for: SeerrItemRoute.self) { route in
                SeerrItemDetailView(route: route)
            }
            .navigationDestination(for: GenreRoute.self) { route in
                LibraryItemsView(genre: route)
            }
            .navigationDestination(for: StudioRoute.self) { route in
                LibraryItemsView(studio: route)
            }
            .navigationDestination(for: StudiosRoute.self) { _ in
                StudiosView()
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                LibraryItemsView(library: route.library)
            }
    }
}

struct LibraryRoute: Hashable {
    let library: BaseItemDto
}
