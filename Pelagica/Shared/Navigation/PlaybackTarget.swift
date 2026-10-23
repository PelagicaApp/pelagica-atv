//
//  PlaybackTarget.swift
//  Pelagica
//

import JellyfinAPI
import Foundation

struct PlaybackTarget: Identifiable {
    let id = UUID()
    let item: BaseItemDto
    let startTicks: Int
}
