//
//  PageLoadingView.swift
//  Pelagica
//

import SwiftUI

struct PageLoadingView: View {
    var text: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                ProgressView()
                Text(text)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PageLoadingView(text: "Restoring session...")
}
