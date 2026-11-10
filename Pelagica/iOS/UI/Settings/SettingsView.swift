//
//  SettingsView.swift
//  Pelagica
//

import JellyfinAPI
import PelagicaI18n
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ThemeSongPlayer.enabledDefaultsKey) private var playThemeSongs = true

    var body: some View {
        NavigationStack {
            Form {
                Section(i18n.t("settings:account_section_title")) {
                    accountRow
                    
                }
                
                if seerrStore.isConfigured {
                    Section {
                        LabeledContent(seerrStatusText) {
                            if seerrStore.isLoggedIn {
                                Button(i18n.t("sidebar:seerr_logout_action")) { seerrStore.logout() }
                            }
                        }
                        if !seerrStore.isLoggedIn {
                            NavigationLink(i18n.t("sidebar:seerr_login_action")) {
                                SeerrLoginView()
                            }
                        }
                    } header: {
                        Text(i18n.t("settings:seerr_integration"))
                    } footer: {
                        if let seerrURL = seerrStore.seerrURL { Text(seerrURL) }
                    }
                }
                
                Section(i18n.t("settings:language_section_title")) {
                    Picker(i18n.t("sidebar:select_language"), selection: languageSelection) {
                        Text("🌐 \(i18n.t("sidebar:system"))").tag(String?.none)
                        ForEach(i18n.supportedLanguages, id: \.code) { language in
                            Text("\(language.country.flagEmoji ?? "") \(language.label)").tag(Optional(language.code))
                        }
                    }
                }
                
                Section(i18n.t("settings:category_itempage")) {
                    Toggle(i18n.t("settings:play_theme_songs_label"), isOn: $playThemeSongs)
                        .tint(.green)
                }
                
                Section {
                    SubtitleStyleSettings()
                } header: {
                    Text(i18n.t("subtitles"))
                } footer: {
                    Text(i18n.t("settings:subtitle_style_description"))
                }

                Section(i18n.t("settings:about_section_title")) {
                    LabeledContent(i18n.t("settings:version_label"), value: appVersionString)
                    NavigationLink(i18n.t("settings:attributions_title")) {
                        AttributionsView()
                    }
                    NavigationLink(i18n.t("settings:open_source_licenses_title")) {
                        LicensesView()
                    }
                }
            }
            .navigationTitle(i18n.t("settings:title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
        }
    }

    private var accountRow: some View {
        HStack(spacing: 14) {
            AsyncImage(url: userImageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.currentUser?.name ?? i18n.t("sidebar:unknown_user"))
                    .font(.headline)
                Text(appState.serverName ?? appState.client?.configuration.url.absoluteString ?? i18n.t("player:unknown"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var userImageURL: URL? {
        guard let id = appState.currentUser?.id, let tag = appState.currentUser?.primaryImageTag, let client = appState.client else { return nil }
        let request = Paths.getUserImage(parameters: Paths.GetUserImageParameters(userID: id, tag: tag))
        return client.url(with: request, queryAPIKey: true)
    }

    private var seerrStatusText: String {
        guard seerrStore.isLoggedIn else { return i18n.t("sidebar:seerr_not_connected") }
        guard let name = seerrStore.user?.displayName, !name.isEmpty else { return i18n.t("sidebar:seerr_connected") }
        return "\(i18n.t("sidebar:seerr_connected")) ⋅ \(name)"
    }

    private var languageSelection: Binding<String?> {
        Binding(
            get: { i18n.languageOverride },
            set: { i18n.setLanguageOverride($0) }
        )
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
