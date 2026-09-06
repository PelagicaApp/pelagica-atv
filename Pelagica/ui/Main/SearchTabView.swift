//
//  SearchTabView.swift
//  Pelagica
//

import SwiftUI

struct SearchTabView: View {
    @State private var query = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Search")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PelagicaField(placeholder: "Movies, shows, actors...", text: $query, label: "Search")

                Spacer()
            }
            .padding(60)
        }
    }
}

#Preview {
    SearchTabView()
}
