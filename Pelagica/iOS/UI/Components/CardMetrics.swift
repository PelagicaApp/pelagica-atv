//
//  CardMetrics.swift
//  Pelagica
//

import SwiftUI

enum CardMetrics {
    static func scale(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 1.4 : 1
    }

    static func landscapeScale(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 1.2 : 1
    }

    static func gridColumns(minimum: CGFloat, spacing: CGFloat, _ sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum * scale(sizeClass)), spacing: spacing * scale(sizeClass))]
    }
}
