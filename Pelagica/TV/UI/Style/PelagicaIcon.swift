//
//  JellyfishIcon.swift
//  Pelagica
//

import SwiftUI

struct PelagicaIcon: View {
    var size: CGFloat = 64

    var body: some View {
        Image("pelagicaLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

#Preview {
    PelagicaIcon()
        .padding()
        .background(Color.black)
}
