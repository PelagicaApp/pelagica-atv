//
//  SettingsView.swift
//  Pelagica
//

import JellyfinAPI
import PelagicaI18n
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName
    @AppStorage(ThemeSongPlayer.enabledDefaultsKey) private var playThemeSongs = true
    
    private let icons: [AppIconOption] = [
        AppIconOption(name: nil, assetName: "AppIconDefault", label: i18n.t("sidebar:app_icon_classic")),
        AppIconOption(name: "AppIconPride", assetName: "AppIconPride", label: i18n.t("sidebar:app_icon_pride")),
        AppIconOption(name: "AppIconLight", assetName: "AppIconLight", label: i18n.t("sidebar:app_icon_classic_light")),
    ]
    
    var body: some View {
        NavigationStack {
            content
        }
    }
    
    private var content: some View {
        ZStack {
            PelagicaBackground()
            
            VStack(alignment: .leading, spacing: 40) {
                Text(i18n.t("settings:title"))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                
                SettingsSection(title: i18n.t("settings:account_section_title")) {
                    profileSection
                }
                
                SettingsSection(title: i18n.t("settings:language_section_title")) {
                    languageSection
                }
                
                SettingsSection(title: i18n.t("settings:category_itempage")) {
                    itemPageSection
                }
                
                SettingsSection(title: i18n.t("sidebar:app_icon")) {
                    HStack(spacing: 34) {
                        ForEach(icons) { icon in
                            AppIconButton(
                                icon: icon,
                                isSelected: currentIconName == icon.name
                            ) {
                                changeAppIcon(to: icon.name)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                SettingsSection(title: i18n.t("settings:about_section_title")) {
                    aboutSection
                }
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    // MARK: - About section
    
    private var aboutSection: some View {
        HStack(spacing: 15) {
            Text("\(i18n.t("settings:version_label")) \(appVersionString)")
                .foregroundStyle(.white)
                .font(.system(size: 28, weight: .semibold))
            
            Spacer()
            
            NavigationLink {
                AttributionsView()
            } label: {
                Text(i18n.t("settings:attributions_title"))
            }
            .buttonStyle(PelagicaButtonStyle(emphasis: .plain))
            .frame(maxWidth: 320)
        }
    }
    
    // MARK: - Profile section
    
    private var profileSection: some View {
        HStack(spacing: 15) {
            ProfileImageView(url: userProfileImageUrl)
                .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(appState.currentUser?.name ?? i18n.t("sidebar:unknown_user"))
                    .foregroundStyle(.white)
                    .font(.system(size: 34, weight: .bold))
                    .lineLimit(1)
                
                Text((appState.serverName ?? i18n.t("player:unknown")) + " ⋅ " + (appState.client?.configuration.url.absoluteString ?? i18n.t("player:unknown")))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                appState.switchProfile()
            } label: {
                Text(i18n.t("profiles:switch_profile"))
            }
            .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
            .frame(maxWidth: 320)
            
            Button {
                appState.signOut()
            } label: {
                Text(i18n.t("sidebar:logout"))
            }
            .buttonStyle(PelagicaButtonStyle(emphasis: .secondary))
            .frame(maxWidth: 250)
        }
    }
    
    private var userProfileImageUrl: URL? {
        guard let id = appState.currentUser?.id, let tag = appState.currentUser?.primaryImageTag, let client = appState.client else { return nil }
        let request = Paths.getUserImage(parameters: Paths.GetUserImageParameters(
            userID: id,
            tag: tag
        ))
        return client.url(with: request, queryAPIKey: true)
    }
    
    // MARK: - Language section
    
    private var languageSection: some View {
        HStack(spacing: 15) {
            Text(currentLanguageLabel)
                .foregroundStyle(.white)
                .font(.system(size: 28, weight: .semibold))
            
            Spacer()
            
            Menu {
                Picker(i18n.t("settings:language_section_title"), selection: languageSelection) {
                    Text(i18n.t("sidebar:system"))
                        .tag(String?.none)
                    ForEach(i18n.supportedLanguages) { language in
                        Text(language.label)
                            .tag(Optional(language.code))
                    }
                }
            } label: {
                Label(i18n.t("sidebar:select_language"), systemImage: "globe")
            }
            .frame(maxWidth: 400)
        }
    }
    
    private var languageSelection: Binding<String?> {
        Binding(
            get: { i18n.languageOverride },
            set: { i18n.setLanguageOverride($0) }
        )
    }
    
    private var currentLanguageLabel: String {
        let label = i18n.supportedLanguages.first { $0.code == i18n.language }?.label ?? i18n.language
        return i18n.languageOverride == nil ? "\(i18n.t("sidebar:system")) (\(label))" : label
    }
    
    // MARK: - Item page section
    
    private var itemPageSection: some View {
        Toggle(isOn: $playThemeSongs) {
            Text(i18n.t("settings:play_theme_songs_label"))
        }
        .toggleStyle(PelagicaToggleStyle())
        .padding(.horizontal, -20)
        .padding(.vertical, -14)
    }
    
    // MARK: - App Icon section
    
    private func changeAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error {
                print("Failed to change icon: \(error.localizedDescription)")
            } else {
                currentIconName = iconName
            }
        }
    }
}

private struct AppIconOption: Identifiable {
    let name: String?
    let assetName: String
    let label: String
    
    var id: String { name ?? "default" }
}

private struct AppIconButton: View {
    let icon: AppIconOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                Image(icon.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                    )
            }
            .buttonStyle(.card)
            
            Text(icon.label)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
            
            content
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        }
        .frame(alignment: .leading)
        .focusSection()
    }
}

private struct ProfileImageView: View {
    let url: URL?
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.3))
                    .background(Color.white.opacity(0.06))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
