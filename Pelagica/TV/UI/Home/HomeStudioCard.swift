//
//  HomeStudioCard.swift
//  Pelagica
//

import SwiftUI

struct HomeStudioCard: View {
    let studio: StudioEntry

    @State private var logoURL: URL?
    @State private var isResolvingLogo = true
    @State private var imageFailed = false

    var body: some View {
        NavigationLink(value: StudioRoute(id: studio.id, name: studio.name)) {
            StudioCardFrame {
                if let logoURL, !imageFailed {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().padding(36)
                        case .failure:
                            Color.clear.onAppear { imageFailed = true }
                        default:
                            EmptyView()
                        }
                    }
                } else if !isResolvingLogo {
                    StudioCardLabel(text: studio.name)
                }
            }
        }
        .buttonStyle(.card)
        .task(id: studio.name) {
            let path = await StudioLogos.shared.logoPath(for: studio.name)
            logoURL = path.flatMap { StudioLogos.logoURL(for: $0) }
            isResolvingLogo = false
        }
    }
}

struct HomeStudiosMoreCard: View {
    var body: some View {
        NavigationLink(value: StudiosRoute()) {
            StudioCardFrame {
                StudioCardLabel(text: i18n.t("home:more"))
            }
        }
        .buttonStyle(.card)
    }
}

private struct StudioCardFrame<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            Color.white.opacity(0.06)
            content()
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct StudioCardLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(Color(white: 0.8))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 24)
    }
}
