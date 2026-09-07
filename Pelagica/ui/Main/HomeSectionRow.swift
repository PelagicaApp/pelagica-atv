//
//  HomeSectionRow.swift
//  Pelagica
//

import SwiftUI

struct HomeSectionRow<Content: View>: View {
    let title: String
    var isLoadingTitle: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoadingTitle {
                SkeletonView()
                    .frame(width: 260, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 60)
            } else if !title.isEmpty {
                Text(title)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    content()
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
    }
}
