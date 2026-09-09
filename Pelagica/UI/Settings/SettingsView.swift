//
//  SettingsView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName
    
    private let icons: [AppIconOption] = [
        AppIconOption(name: nil, assetName: "AppIconDefault", label: "Default"),
        AppIconOption(name: "AppIconPride", assetName: "AppIconPride", label: "Pride"),
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 40) {
                Text("Settings")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                
                SettingsSection(title: "Account") {
                    profileSection
                }
                
                SettingsSection(title: "App Icon") {
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
                
                Text("Pelagica for AppleTV \(appVersionString)")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18, weight: .semibold))
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
    
    // MARK: - Profile section
    
    private var profileSection: some View {
        HStack(spacing: 15) {
            ProfileImageView(url: userProfileImageUrl)
                .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(appState.currentUser?.name ?? "Unknown")
                    .foregroundStyle(.white)
                    .font(.system(size: 34, weight: .bold))
                    .lineLimit(1)
                
                Text((appState.serverName ?? "Unknown") + " ⋅ " + (appState.client?.configuration.url.absoluteString ?? "Unknown"))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                appState.signOut()
            } label: {
                Text("Sign Out")
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
