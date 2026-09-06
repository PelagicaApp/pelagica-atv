//
//  SkeletonView.swift
//  Pelagica
//

import SwiftUI

struct SkeletonView: View {
    @State private var isPulsing = false
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(isPulsing ? 0.12 : 0.05))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
