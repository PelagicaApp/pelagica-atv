//
//  ProfileMenu.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ShowSettingsAction: Equatable {
    var action: () -> Void = {}

    func callAsFunction() { action() }

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
    @Entry var showSettings = ShowSettingsAction()
}

extension View {
    func profileToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton()
            }
        }
    }
}

struct ProfileMenuButton: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore
    @Environment(\.showSettings) private var showSettings

    @State private var menuImages: [UUID: UIImage] = [:]

    var body: some View {
        Menu {
            Section {
                ForEach(appState.profiles) { profile in
                    Toggle(isOn: isActive(profile)) {
                        Label {
                            Text(profile.userName)
                        } icon: {
                            menuIcon(for: profile)
                        }
                        Text(profile.serverName)
                    }
                }

                Button(i18n.t("profiles:switch_profile"), systemImage: "person.2") {
                    appState.switchProfile()
                }
            }

            Section {
                Button(i18n.t("settings:title"), systemImage: "gearshape") {
                    showSettings()
                }
            }

            Section {
                Button(i18n.t("sidebar:logout"), systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    seerrStore.logout()
                    appState.signOut()
                }
            }
        } label: {
            avatar
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(appState.currentUser?.name ?? i18n.t("sidebar:unknown_user"))
        .task(id: appState.profiles) { await loadMenuImages() }
    }

    @ViewBuilder
    private func menuIcon(for profile: Profile) -> some View {
        if let image = menuImages[profile.id] {
            Image(uiImage: image)
        } else {
            Image(systemName: "person.crop.circle.fill")
        }
    }

    private var avatar: some View {
        AsyncImage(url: avatarURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.12))
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private var avatarURL: URL? {
        appState.activeProfile.flatMap(appState.profileImageURL(for:))
    }

    private func isActive(_ profile: Profile) -> Binding<Bool> {
        Binding(
            get: { profile.id == appState.activeProfile?.id },
            set: { isOn in
                guard isOn, profile.id != appState.activeProfile?.id else { return }
                select(profile)
            }
        )
    }

    private func loadMenuImages() async {
        for profile in appState.profiles where menuImages[profile.id] == nil {
            guard let url = appState.profileImageURL(for: profile),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data)
            else { continue }
            menuImages[profile.id] = Self.circularMenuImage(from: image)
        }
    }

    private static func circularMenuImage(from image: UIImage, side: CGFloat = 28) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let scale = max(side / image.size.width, side / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
        return UIGraphicsImageRenderer(bounds: bounds).image { _ in
            UIBezierPath(ovalIn: bounds).addClip()
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        .withRenderingMode(.alwaysOriginal)
    }

    private func select(_ profile: Profile) {
        appState.switchProfile()
        Task { try? await appState.selectProfile(profile) }
    }
}
