//
//  QRCodeGenerator.swift
//  Pelagica
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    static func generate(from string: String, scale: CGFloat = 10) -> CGImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }
}
