//
//  MediaSourceVersion.swift
//  Pelagica
//

import Foundation
import JellyfinAPI

extension MediaSourceInfo {
    var versionName: String {
        name ?? container ?? i18n.t("player:unknown")
    }

    var versionSize: String? {
        guard let size, size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var versionTitle: String {
        guard let versionSize else { return versionName }
        return "\(versionName) · \(versionSize)"
    }
}
