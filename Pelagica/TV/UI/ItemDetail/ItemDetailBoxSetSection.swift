//
//  ItemDetailBoxSetSection.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailBoxSetSection: View {
    let items: [BaseItemDto]
    let nextItemID: String?
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(i18n.t("item:boxSetItems"))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 90)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 32) {
                    ForEach(items, id: \.id) { item in
                        ItemCard(item: item)
                            .frame(width: 280)
                            .prefersDefaultFocus(item.id == (nextItemID ?? items.first?.id), in: namespace)
                    }
                }
                .padding(.horizontal, 90)
            }
            .scrollClipDisabled()
        }
        .focusScope(namespace)
        .focusSection()
    }
}
