//
//  ItemDetailCasetAndCrewSection.swift
//  Pelagica
//

import JellyfinAPI
import SwiftUI

struct ItemDetailsPeopleSection: View {
    let people: [BaseItemPerson]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(i18n.t("item:cast_and_crew"))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 90)
            
            peopleRow
                .focusSection()
        }
    }
    
    private var peopleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 32) {
                ForEach(people, id: \.id) { person in
                    PersonCard(person: person)
                }
            }
            .padding(.horizontal, 90)
        }
        .scrollClipDisabled()
    }
}

private struct PersonCard: View {
    @EnvironmentObject private var appState: AppState
    let person: BaseItemPerson
    
    var body: some View {
        VStack(spacing: 20) {
            NavigationLink(value: person.id.map { PersonDetailRoute(id: $0, name: person.name) }) {
                profilePicture
            }
            .buttonStyle(.card)
            .buttonBorderShape(.circle)
            
            VStack(spacing: 4) {
                Text(person.name ?? i18n.t("item:unknown_item"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .lineLimit(1)
            .multilineTextAlignment(.center)
        }
        .frame(width: 150)
    }
    
    private var subtitle: String? {
        if let role = person.role, !role.isEmpty { return role }
        return person.type?.rawValue
    }
    
    private var profilePicture: some View {
        AsyncImage(url: imageURL) { phase in
            ZStack {
                SkeletonView()
                    .opacity(phase.image == nil && !isFailure(phase) ? 1 : 0)
                fallbackIcon
                    .opacity(isFailure(phase) ? 1 : 0)
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipped()
                }
            }
        }
        .frame(width: 150, height: 150)
    }
    
    private var fallbackIcon: some View {
        Image(systemName: "person")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.3))
    }
    
    private var imageURL: URL? {
        guard let id = person.id, let client = appState.client else { return nil }
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(fillWidth: 300, fillHeight: 300)
        )
        return client.url(with: request, queryAPIKey: true)
    }
    
    private func isFailure(_ phase: AsyncImagePhase) -> Bool {
        if case .failure = phase { return true }
        return false
    }
}
