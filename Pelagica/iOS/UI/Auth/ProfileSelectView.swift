//
//  ProfileSelectView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ProfileSelectView: View {
    @EnvironmentObject private var appState: AppState

    @State private var signingInID: UUID?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 24)]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                AuthHeader()

                Text(i18n.t("profiles:who_is_watching"))
                    .font(.title2.weight(.semibold))

                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(appState.profiles) { profile in
                        Button {
                            select(profile)
                        } label: {
                            profileTile(profile)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(i18n.t("profiles:remove_profile"), systemImage: "trash", role: .destructive) {
                                appState.removeProfile(profile)
                            }
                        }
                    }

                    Button {
                        appState.beginAddingProfile()
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 96, height: 96)
                                .background(Color.white.opacity(0.08), in: Circle())
                            Text(i18n.t("profiles:add_profile"))
                                .font(.subheadline.weight(.semibold))
                            Text(" ").font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .disabled(signingInID != nil)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
    }

    private func profileTile(_ profile: Profile) -> some View {
        VStack(spacing: 10) {
            AsyncImage(url: appState.profileImageURL(for: profile)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay {
                if signingInID == profile.id {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black.opacity(0.5), in: Circle())
                }
            }

            Text(profile.userName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(profile.serverName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func select(_ profile: Profile) {
        errorMessage = nil
        signingInID = profile.id
        Task {
            defer { signingInID = nil }
            do {
                try await appState.selectProfile(profile)
            } catch {
                errorMessage = i18n.t("profiles:couldnt_reach_server", ["server": profile.serverName])
            }
        }
    }
}
