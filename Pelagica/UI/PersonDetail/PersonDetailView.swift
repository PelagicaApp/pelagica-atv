//
//  PersonDetailView.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct PersonDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore

    @StateObject private var model: PersonDetailModel
    @State private var isShowingBiography = false

    @Namespace private var heroNamespace
    @FocusState private var isHeroFocused: Bool

    private static let topScrollAnchor = "personTop"

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    init(route: PersonDetailRoute) {
        _model = StateObject(wrappedValue: PersonDetailModel(route: route))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 80) {
                    heroSection
                        .id(Self.topScrollAnchor)
                        .focusScope(heroNamespace)
                        .focusSection()

                    filmographySection

                    if !model.seerrCredits.isEmpty {
                        SeerrItemsRow(title: i18n.t("item:known_for"), items: model.seerrCredits)
                            .padding(.horizontal, -90)
                    }
                }
                .padding(.horizontal, 90)
                .padding(.vertical, 60)
            }
            .onChange(of: isHeroFocused) { _, isFocused in
                guard isFocused else { return }
                withAnimation { proxy.scrollTo(Self.topScrollAnchor, anchor: .top) }
            }
        }
        .background(PelagicaBackground())
        .task {
            model.bind(appState: appState, seerrStore: seerrStore)
            await model.load()
        }
        .sheet(isPresented: $isShowingBiography) {
            biographySheet
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 60) {
            portraitImage
                .focusable()
                .focused($isHeroFocused)
                .prefersDefaultFocus(true, in: heroNamespace)

            VStack(alignment: .leading, spacing: 24) {
                Text(model.name)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)

                if !model.facts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.facts, id: \.label) { fact in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(fact.label)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(fact.value)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .font(.system(size: 24, weight: .medium))
                }

                if model.hasBiography, let overview = model.person?.overview {
                    Text(overview)
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 1100, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var portraitImage: some View {
        ZStack {
            Color.white.opacity(0.06)

            AsyncImage(url: model.portraitURL(width: 640, height: 960)) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && !isFailure(phase) && !model.hasNoPortrait ? 1 : 0)
                    Image(systemName: "person")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(isFailure(phase) || model.hasNoPortrait ? 1 : 0)
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: 320, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.85), radius: 40, y: 25)
    }

    private var biographySheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text(model.person?.name ?? model.route.name ?? "")
                    .font(.system(size: 48, weight: .bold))
                Text(model.person?.overview ?? "")
                    .font(.system(size: 26))
            }
            .frame(maxWidth: 1200, alignment: .leading)
            .padding(60)
            .focusable()
        }
    }

    // MARK: - Filmography

    @ViewBuilder
    private var filmographySection: some View {
        if model.isLoadingFilmography || !model.filmography.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
                Text(i18n.t("item:filmography"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                LazyVGrid(columns: columns, spacing: 60) {
                    if model.isLoadingFilmography {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonView()
                                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        ForEach(model.filmography, id: \.id) { item in
                            ItemCard(item: item)
                        }
                    }
                }
            }
            .focusSection()
        }
    }

    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}

#Preview {
    PersonDetailView(route: PersonDetailRoute(id: "preview", name: "Preview Person"))
        .environmentObject(AppState())
        .environmentObject(SeerrStore())
}
