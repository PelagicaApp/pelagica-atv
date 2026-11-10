//
//  ItemDetailCollectionsSection.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailCollectionsSection: View {
    let collectionItems: [String: [BaseItemDto]]

    var body: some View {
        VStack(alignment: .leading, spacing: 60) {
            ForEach(collectionItems.sorted(by: { $0.key < $1.key }), id: \.key) { name, items in
                CollectionRow(name: name, items: items)
            }
        }
    }
}

private struct CollectionRow: View {
    let name: String
    let items: [BaseItemDto]

    @Namespace private var rowNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(name)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 90)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 32) {
                    ForEach(items, id: \.id) { item in
                        ItemCard(item: item)
                            .frame(width: 280)
                            .prefersDefaultFocus(item.id == items.first?.id, in: rowNamespace)
                    }
                }
                .padding(.horizontal, 90)
            }
            .scrollClipDisabled()
        }
        .focusScope(rowNamespace)
        .focusSection()
    }
}
