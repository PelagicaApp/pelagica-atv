//
//  DetailBadges.swift
//  Pelagica
//

import Foundation
import JellyfinAPI

enum DetailBadgeIcon {
    case star
    case award
}

struct DetailBadgeValue {
    var text: String
    var icon: DetailBadgeIcon?
}

enum DetailBadges {
    static let defaultBadges: [DetailBadge] = [.releaseYear, .communityRating, .ageRating, .episodeNumber]

    static func value(for item: BaseItemDto, type: DetailBadge) -> DetailBadgeValue? {
        switch type {
        case .releaseYear:
            guard let date = item.premiereDate else { return nil }
            return DetailBadgeValue(text: String(Calendar.current.component(.year, from: date)))

        case .releaseYearAndMonth:
            guard let date = item.premiereDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return DetailBadgeValue(text: formatter.string(from: date))

        case .releaseDate:
            guard let date = item.premiereDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return DetailBadgeValue(text: formatter.string(from: date))

        case .communityRating:
            guard let rating = item.communityRating else { return nil }
            return DetailBadgeValue(text: String(format: "%.1f", rating), icon: .star)

        case .criticsRating:
            guard let rating = item.criticRating else { return nil }
            return DetailBadgeValue(text: "\(Int(rating.rounded()))%", icon: .award)

        case .playDuration, .duration:
            guard let ticks = item.runTimeTicks else { return nil }
            return DetailBadgeValue(text: readableTime(ticks: ticks))

        case .playEnd:
            guard let ticks = item.runTimeTicks else { return nil }
            let endsAt = Date().addingTimeInterval(Double(ticks) / 10_000_000)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return DetailBadgeValue(text: "Ends at \(formatter.string(from: endsAt))")

        case .seasonCount:
            guard let count = item.childCount else { return nil }
            return DetailBadgeValue(text: count == 1 ? "1 Season" : "\(count) Seasons")

        case .episodeCount:
            guard let count = item.recursiveItemCount else { return nil }
            return DetailBadgeValue(text: count == 1 ? "1 Episode" : "\(count) Episodes")

        case .ageRating:
            guard let rating = item.officialRating else { return nil }
            return DetailBadgeValue(text: rating)

        case .episodeNumber:
            guard let season = item.parentIndexNumber, let episode = item.indexNumber else { return nil }
            return DetailBadgeValue(text: "S\(season) E\(episode)")

        case .videoQuality:
            guard let streams = item.mediaStreams else { return nil }
            return DetailBadgeValue(text: videoQualityLabel(streams: streams))
        }
    }

    private static func readableTime(ticks: Int) -> String {
        let totalMinutes = ticks / 10_000_000 / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private static func videoQualityLabel(streams: [MediaStream]) -> String {
        let videoStream = streams
            .filter { $0.type == .video }
            .max { ($0.height ?? 0) < ($1.height ?? 0) }
        guard let height = videoStream?.height, height > 0 else { return "Unknown" }

        switch height {
        case 2160...: return "4K"
        case 1440..<2160: return "2K"
        case 1080..<1440: return "Full HD"
        case 720..<1080: return "HD"
        case 480..<720: return "SD"
        default: return "Potato Quality"
        }
    }
}
