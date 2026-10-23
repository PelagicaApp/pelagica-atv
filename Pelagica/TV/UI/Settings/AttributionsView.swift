//
//  AttributionsView.swift
//  Pelagica
//

import SwiftUI

struct AttributionsView: View {
    var body: some View {
        ZStack {
            PelagicaBackground()

            VStack(alignment: .leading, spacing: 40) {
                Text(i18n.t("settings:attributions_title"))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 28) {
                    Image("tmdb")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)

                    Text(i18n.t("settings:tmdb_attribution"))
                        .foregroundStyle(.secondary)
                        .font(.system(size: 24))

                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

                NavigationLink {
                    LicensesView()
                } label: {
                    Text(i18n.t("settings:open_source_licenses_title"))
                }
                .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
                .frame(maxWidth: 480)
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview {
    AttributionsView()
}
