//
//  PersonDetailModel.swift
//  Pelagica
//

import Combine
import Foundation
import Get
import JellyfinAPI

@MainActor
final class PersonDetailModel: ObservableObject {
    struct Fact {
        let label: String
        let value: String
    }

    let route: PersonDetailRoute

    @Published private(set) var person: BaseItemDto?
    @Published private(set) var filmography: [BaseItemDto] = []
    @Published private(set) var isLoadingFilmography = true
    @Published private(set) var seerrCredits: [SeerrMediaItem] = []

    private var appState: AppState?
    private var seerrStore: SeerrStore?

    init(route: PersonDetailRoute) {
        self.route = route
    }

    func bind(appState: AppState, seerrStore: SeerrStore) {
        self.appState = appState
        self.seerrStore = seerrStore
    }

    func load() async {
        await loadPerson()
        await loadFilmography()
        await loadSeerrCredits()
    }

    // MARK: - Derived state

    var name: String {
        person?.name ?? route.name ?? i18n.t("item:unknown_item")
    }

    var hasBiography: Bool {
        person?.overview?.isEmpty == false
    }

    var hasNoPortrait: Bool {
        person != nil && person?.imageTags?["Primary"] == nil
    }

    var facts: [Fact] {
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

    func portraitURL(width: Int, height: Int) -> URL? {
        guard let client = appState?.client,
              let tag = person?.imageTags?["Primary"] else { return nil }
        let request = Paths.getItemImage(
            itemID: route.id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(fillWidth: width, fillHeight: height, tag: tag)
        )
        return client.url(with: request, queryAPIKey: true)
    }

    // MARK: - Data loading

    private func loadPerson() async {
        guard let client = appState?.client else { return }
        do {
            person = try await client.send(Paths.getItem(itemID: route.id, userID: appState?.currentUser?.id)).value
        } catch {
            // The name from the route is enough to render the page.
        }
    }

    private func loadFilmography() async {
        defer { isLoadingFilmography = false }
        guard let client = appState?.client else { return }
        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: appState?.currentUser?.id,
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
        guard let seerrStore, let tmdbID = person?.providerIDs?["Tmdb"], !tmdbID.isEmpty else { return }
        seerrCredits = await seerrStore.items { try await $0.combinedCredits(personTmdbID: tmdbID) }
    }
}
