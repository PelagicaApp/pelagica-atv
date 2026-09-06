//
//  LibraryItemsView.swift
//  Pelagica
//

import Get
import JellyfinAPI
import SwiftUI

struct LibraryItemsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let library: BaseItemDto

    @State private var items: [BaseItemDto] = []
    @State private var totalCount: Int?
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    /// How many items from the end of the loaded list trigger fetching the next batch.
    private let prefetchThreshold = 8
    private let batchSize = 48
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 40)]

    private var hasMore: Bool {
        guard let totalCount else { return true }
        return items.count < totalCount
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(library.name ?? "Library")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    } else if (items.isEmpty){
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 60) {
                            ForEach(items) { item in
                                ItemCard(item: item)
                                    .onAppear { loadMoreIfNeeded(current: item) }
                            }

                            if isLoadingMore {
                                ForEach(0..<prefetchThreshold, id: \.self) { _ in
                                    SkeletonView()
                                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                }
                .padding(60)
            }
        }
        .task {
            guard items.isEmpty else { return }
            isLoadingMore = true
            await loadMore()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("Nothing here yet")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("This library doesn't have any items in it.")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            
            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.system(size: 20, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.card)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func loadMoreIfNeeded(current item: BaseItemDto) {
        guard hasMore, !isLoadingMore else { return }
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard itemIndex >= items.count - prefetchThreshold else { return }

        isLoadingMore = true
        Task { await loadMore() }
    }

    private func loadMore() async {
        defer { isLoadingMore = false }
        guard let client = appState.client, let libraryID = library.id else { return }
        do {
            let result = try await client.send(Paths.getItems(parameters: .init(
                userID: appState.currentUser?.id,
                startIndex: items.count,
                limit: batchSize,
                isRecursive: false,
                sortOrder: [.descending],
                parentID: libraryID,
                sortBy: [.dateCreated]
            ))).value
            items.append(contentsOf: result.items ?? [])
            totalCount = result.totalRecordCount ?? items.count
        } catch {
            errorMessage = "Couldn't load items."
        }
    }
}

private struct ItemCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.displayScale) private var displayScale
    let item: BaseItemDto
    
    private let cornerRadius: CGFloat = 16
    private let posterAspectRatio: CGFloat = 2.0 / 3.0
    
    @State private var measuredWidth: CGFloat?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            Button {
                // Item detail isn't implemented yet.
            } label: {
                GeometryReader { proxy in
                    posterBody(size: proxy.size)
                        .onAppear { updateMeasuredWidth(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, newValue in
                            updateMeasuredWidth(newValue)
                        }
                }
                .aspectRatio(posterAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(item.name ?? "Untitled")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(item.premiereDate.map { String(Calendar.current.component(.year, from: $0)) } ?? "")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private func posterBody(size: CGSize) -> some View {
        ZStack {
            Color.white.opacity(0.06)
            
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                case .failure:
                    fallbackIcon
                case .empty:
                    SkeletonView()
                @unknown default:
                    fallbackIcon
                }
            }
            .animation(nil, value: measuredWidth)
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        if let measuredWidth, abs(measuredWidth - width) < 1 { return }
        measuredWidth = width
    }
    
    private var fallbackIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 32))
            .foregroundStyle(.white.opacity(0.3))
    }
    
    private var imageURL: URL? {
        guard let id = item.id, let client = appState.client, let measuredWidth else { return nil }
        
        let pixelWidth = Int((measuredWidth * displayScale).rounded())
        let pixelHeight = Int((measuredWidth * displayScale / posterAspectRatio).rounded())
        
        let request = Paths.getItemImage(
            itemID: id,
            imageType: ImageType.primary.rawValue,
            parameters: .init(
                fillWidth: pixelWidth,
                fillHeight: pixelHeight,
                tag: item.imageTags?["Primary"]
            )
        )
        return client.url(with: request, queryAPIKey: true)
    }
}

#Preview {
    LibraryItemsView(library: BaseItemDto(name: "Movies"))
        .environmentObject(AppState())
}
