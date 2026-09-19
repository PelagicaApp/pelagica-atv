//
//  ProfileSelectView.swift
//  Pelagica
//

import SwiftUI

struct ProfileSelectView: View {
    @EnvironmentObject private var appState: AppState

    @State private var signingInID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        PelagicaScreen {
            PelagicaHeader()

            Text("Who's watching?")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 48) {
                    ForEach(appState.profiles) { profile in
                        ProfileCard(
                            profile: profile,
                            imageURL: appState.profileImageURL(for: profile),
                            isLoading: signingInID == profile.id
                        ) {
                            select(profile)
                        } onRemove: {
                            appState.removeProfile(profile)
                        }
                        .disabled(signingInID != nil)
                    }

                    AddProfileCard {
                        appState.beginAddingProfile()
                    }
                    .disabled(signingInID != nil)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
            .defaultScrollAnchor(.center)
            .focusSection()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
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
                errorMessage = "Couldn't reach \(profile.serverName)."
            }
        }
    }
}

private struct ProfileCard: View {
    let profile: Profile
    let imageURL: URL?
    let isLoading: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onSelect) {
                ProfileAvatar(url: imageURL)
                    .frame(width: 200, height: 200)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                    }
            }
            .buttonStyle(PelagicaCircleButtonStyle(diameter: 200))
            .contextMenu {
                Button("Remove Profile", role: .destructive, action: onRemove)
            }

            VStack(spacing: 4) {
                Text(profile.userName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(profile.serverName)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 240)
        }
    }
}

private struct AddProfileCard: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 200, height: 200)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5))
            }
            .buttonStyle(PelagicaCircleButtonStyle(diameter: 200))

            Text("Add Profile")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 240)
            // Keeps the label aligned with the profile cards' two-line captions.
            Color.clear.frame(height: 24)
        }
    }
}

private struct ProfileAvatar: View {
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

#Preview {
    ProfileSelectView()
        .environmentObject(AppState())
}
