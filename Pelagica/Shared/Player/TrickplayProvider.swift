//
//  TrickplayProvider.swift
//  Pelagica
//

import CoreGraphics
import Foundation
import Get
import ImageIO
import JellyfinAPI

/// Serves scrubbing thumbnails from Jellyfin's trickplay sprite sheets.
/// Each tile is a JPEG grid of `tileWidth` x `tileHeight` thumbnails, one every `interval` milliseconds.
final class TrickplayProvider {
    let thumbnailWidth: Int
    let thumbnailHeight: Int

    private let client: JellyfinClient
    private let itemID: String
    private let mediaSourceID: String
    private let interval: Int
    private let thumbnailCount: Int
    private let columns: Int
    private let rows: Int

    private var tileData: [Int: Data] = [:]
    private var inFlight: [Int: Task<Data?, Never>] = [:]
    private var decodedTiles: [(index: Int, image: CGImage)] = []

    private static let preferredWidth = 320
    private static let decodedTileLimit = 2

    init?(item: BaseItemDto, mediaSourceID: String, client: JellyfinClient) {
        guard
            let itemID = item.id,
            let manifest = item.trickplay,
            let resolutions = Self.resolutions(in: manifest, mediaSourceID: mediaSourceID),
            let info = resolutions
                .compactMap({ key, info in Int(key).map { (width: $0, info: info) } })
                .min(by: { abs($0.width - Self.preferredWidth) < abs($1.width - Self.preferredWidth) })?
                .info,
            let width = info.width, width > 0,
            let height = info.height, height > 0,
            let interval = info.interval, interval > 0,
            let thumbnailCount = info.thumbnailCount, thumbnailCount > 0,
            let columns = info.tileWidth, columns > 0,
            let rows = info.tileHeight, rows > 0
        else { return nil }

        self.client = client
        self.itemID = itemID
        self.mediaSourceID = mediaSourceID
        self.thumbnailWidth = width
        self.thumbnailHeight = height
        self.interval = interval
        self.thumbnailCount = thumbnailCount
        self.columns = columns
        self.rows = rows
    }

    /// The manifest is keyed by media source ID in `N` format; fall back to the only entry if the IDs are formatted differently.
    private static func resolutions(
        in manifest: [String: [String: TrickplayInfoDto]],
        mediaSourceID: String
    ) -> [String: TrickplayInfoDto]? {
        if let exact = manifest[mediaSourceID] { return exact }
        let normalized = mediaSourceID.replacingOccurrences(of: "-", with: "").lowercased()
        if let match = manifest.first(where: { $0.key.replacingOccurrences(of: "-", with: "").lowercased() == normalized }) {
            return match.value
        }
        return manifest.count == 1 ? manifest.first?.value : nil
    }

    func thumbnailIndex(at seconds: TimeInterval) -> Int {
        min(max(0, Int(seconds * 1000) / interval), thumbnailCount - 1)
    }

    func thumbnail(at index: Int) async -> CGImage? {
        let perTile = columns * rows
        let tileIndex = index / perTile
        let local = index % perTile

        prefetch(tileIndex + 1)
        if tileIndex > 0 { prefetch(tileIndex - 1) }

        guard let tile = await decodedTile(tileIndex) else { return nil }
        let rect = CGRect(
            x: (local % columns) * thumbnailWidth,
            y: (local / columns) * thumbnailHeight,
            width: thumbnailWidth,
            height: thumbnailHeight
        )
        return tile.cropping(to: rect)
    }

    private func prefetch(_ tileIndex: Int) {
        guard tileIndex * columns * rows < thumbnailCount else { return }
        _ = loadData(tileIndex)
    }

    private func decodedTile(_ tileIndex: Int) async -> CGImage? {
        if let position = decodedTiles.firstIndex(where: { $0.index == tileIndex }) {
            let entry = decodedTiles.remove(at: position)
            decodedTiles.append(entry)
            return entry.image
        }
        guard let data = await loadData(tileIndex).value else { return nil }
        guard let image = await Self.decode(data) else { return nil }
        if !decodedTiles.contains(where: { $0.index == tileIndex }) {
            decodedTiles.append((tileIndex, image))
            if decodedTiles.count > Self.decodedTileLimit { decodedTiles.removeFirst() }
        }
        return image
    }

    private func loadData(_ tileIndex: Int) -> Task<Data?, Never> {
        if let data = tileData[tileIndex] { return Task { data } }
        if let task = inFlight[tileIndex] { return task }
        let request = Paths.getTrickplayTileImage(
            itemID: itemID,
            width: thumbnailWidth,
            index: tileIndex,
            mediaSourceID: mediaSourceID
        )
        let task = Task { [client] () -> Data? in
            try? await client.send(request).value
        }
        inFlight[tileIndex] = task
        Task {
            let data = await task.value
            inFlight[tileIndex] = nil
            if let data { tileData[tileIndex] = data }
        }
        return task
    }

    @concurrent
    private static func decode(_ data: Data) async -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
}
