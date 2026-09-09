//
//  MainView.swift
//  Pelagica
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            HomeTabView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            SearchTabView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
