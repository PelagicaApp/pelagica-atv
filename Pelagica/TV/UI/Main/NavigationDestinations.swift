//
//  NavigationDestinations.swift
//  Pelagica
//

import SwiftUI

extension View {
    /// Destinations every tab's navigation stack can reach.
    func pelagicaDestinations() -> some View {
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
    }
}
