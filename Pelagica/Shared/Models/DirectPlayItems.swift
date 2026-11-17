//
//  DirectPlayItems.swift
//  Pelagica
//

import JellyfinAPI

extension BaseItemDto {
    var playsDirectly: Bool {
        type == .musicVideo
    }
}

extension CollectionType {
    var playsDirectly: Bool {
        self == .musicvideos
    }
}
