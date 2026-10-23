//
//  AboutViews.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct AttributionsView: View {
    var body: some View {
        List {
            HStack(spacing: 16) {
                Image("tmdb")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60)
                Text(i18n.t("settings:tmdb_attribution"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .navigationTitle(i18n.t("settings:attributions_title"))
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section {
                ForEach(OpenSourceLicense.all) { license in
                    NavigationLink {
                        ScrollView {
                            Text(license.text)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .padding()
                        }
                        .navigationTitle(license.name)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        LabeledContent {
                            Text(license.license)
                        } label: {
                            Text(license.name)
                            if let version = license.version { Text(version) }
                        }
                    }
                }
            } footer: {
                Text(i18n.t("settings:pelagica_license_notice", ["license": "GPL-3.0", "url": "github.com/PelagicaApp/pelagica-atv"]))
            }
        }
        .navigationTitle(i18n.t("settings:open_source_licenses_title"))
    }
}
