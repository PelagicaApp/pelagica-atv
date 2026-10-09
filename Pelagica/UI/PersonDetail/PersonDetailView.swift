//
//  PersonDetailView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct PersonDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var seerrStore: SeerrStore

    let route: PersonDetailRoute

    @State private var person: BaseItemDto?
    @State private var filmography: [BaseItemDto] = []
    @State private var isLoadingFilmography = true
    @State private var seerrCredits: [SeerrMediaItem] = []
    @State private var isShowingBiography = false

    @Namespace private var heroNamespace
    @FocusState private var isHeroFocused: Bool

    private static let topScrollAnchor = "personTop"

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 40)]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 80) {
                    heroSection
                        .id(Self.topScrollAnchor)
                        .focusScope(heroNamespace)
                        .focusSection()

                    filmographySection

                    if !seerrCredits.isEmpty {
                        SeerrItemsRow(title: i18n.t("item:known_for"), items: seerrCredits)
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
            await loadPerson()
            await loadFilmography()
            await loadSeerrCredits()
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
                Text(person?.name ?? route.name ?? i18n.t("item:unknown_item"))
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)

                if !facts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(facts, id: \.label) { fact in
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

                if hasBiography, let overview = person?.overview {
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

            AsyncImage(url: portraitURL) { phase in
                ZStack {
                    SkeletonView()
                        .opacity(phase.image == nil && !isFailure(phase) && !hasNoPortrait ? 1 : 0)
                    Image(systemName: "person")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(isFailure(phase) || hasNoPortrait ? 1 : 0)
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
                Text(person?.name ?? route.name ?? "")
                    .font(.system(size: 48, weight: .bold))
                Text(person?.overview ?? "")
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
        if isLoadingFilmography || !filmography.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
                Text(i18n.t("item:filmography"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                LazyVGrid(columns: columns, spacing: 60) {
                    if isLoadingFilmography {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonView()
                                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        ForEach(filmography, id: \.id) { item in
                            ItemCard(item: item)
                        }
                    }
                }
            }
            .focusSection()
        }
    }

    // MARK: - Facts

    private struct Fact {
        let label: String
        let value: String
    }

    private var facts: [Fact] {
        guard let person else { return [] }
        var facts: [Fact] = []

        if let birth = person.premiereDate {
            var value = birth.formatted(date: .long, time: .omitted)
            if person.endDate == nil, let age = years(from: birth, to: .now) {
                value += " (\(age))"
            }
            facts.append(Fact(label: i18n.t("item:born"), value: value))
        }

        if let death = person.endDate {
            var value = death.formatted(date: .long, time: .omitted)
            if let birth = person.premiereDate, let age = years(from: birth, to: death) {
                value += " (\(age))"
            }
            facts.append(Fact(label: i18n.t("item:died"), value: value))
        }

        if let place = person.productionLocations?.first, !place.isEmpty {
            facts.append(Fact(label: i18n.t("item:birth_place"), value: place))
        }

        return facts
    }

    private func years(from start: Date, to end: Date) -> Int? {
        Calendar.current.dateComponents([.year], from: start, to: end).year
    }

    // MARK: - Data loading

    private func loadPerson() async {
        guard let client = appState.client else { return }
        do {
            person = try await client.send(Paths.getItem(itemID: route.id, userID: appState.currentUser?.id)).value
        } catch {
            // The name from the route is enough to render the page.
        }
    }

    private func loadFilmography() async {
        defer { isLoadingFilmography = false }
        guard let client = appState.client else { return }
        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: appState.currentUser?.id,
                isRecursive: true,
                sortOrder: [.descending],
                includeItemTypes: [.movie, .series],
                sortBy: [.premiereDate, .sortName],
                personIDs: [route.id]
            ))).value
            filmography = result.items ?? []
        } catch {
            filmography = []
        }
    }

    private func loadSeerrCredits() async {
        guard let tmdbID = person?.providerIDs?["Tmdb"], !tmdbID.isEmpty else { return }
        seerrCredits = await seerrStore.items { try await $0.combinedCredits(personTmdbID: tmdbID) }
    }

    // MARK: - Images

    private var portraitURL: URL? {
        guard let client = appState.client,
              let tag = person?.imageTags?["Primary"] else { return nil }
        let request = Paths.getItemImage(
            itemID: route.id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(fillWidth: 640, fillHeight: 960, tag: tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }

    private var hasBiography: Bool {
        person?.overview?.isEmpty == false
    }

    private var hasNoPortrait: Bool {
        person != nil && person?.imageTags?["Primary"] == nil
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
