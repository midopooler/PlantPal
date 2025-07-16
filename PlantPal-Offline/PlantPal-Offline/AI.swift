//
//  AI.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
// Vision framework completely removed - using MobileCLIP only

struct AI {
    static let shared = AI()
    private init() {}
    
    enum Attention {
        case none, zoom(factors: [CGFloat])
    }
    
    // MARK: - Embedding
    
    func embeddings(for image: UIImage, attention: Attention = .none) -> [[Float]] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Process the input image and generate the embeddings
        var embeddings = [[Float]]()
        let processedImages = process(cgImage: cgImage, attention: attention)
        for processedImage in processedImages {
            if let embedding = embedding(for: processedImage) {
                embeddings.append(embedding)
            }
        }
        
        return embeddings
    }
    
    func embedding(for image: UIImage, attention: Attention = .none) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Process the input image and generate the embedding
        var embedding: [Float]?
        if let processedImage = process(cgImage: cgImage, attention: attention).first {
            embedding = self.embedding(for: processedImage)
        }
        
        return embedding
    }
    
    private func embedding(for cgImage: CGImage) -> [Float]? {
        // Scale images to the size required by MobileCLIP.
        let cgImage = fit(cgImage: cgImage, to: CGSize(width: 256, height: 256))
        
        // Use MobileCLIP instead of Vision framework
        return MobileCLIPWrapper.shared.embedding(for: cgImage)
    }
    
    // MARK: - Image Processing
    
    func process(cgImage: CGImage, attention: Attention) -> [CGImage] {
        var processedImages = [CGImage]()
        
        switch attention {
        case .none:
            processedImages.append(cgImage)
        case .zoom(let factors):
            let zoomedImages = zoom(cgImage: cgImage, factors: factors)
            processedImages.append(contentsOf: zoomedImages)
        }
        
        return processedImages
    }
    
    private func zoom(cgImage: CGImage, factors: [CGFloat]) -> [CGImage] {
        var zommedImages = [CGImage]()
        
        for factor in factors {
            let zommedImage = zoom(cgImage: cgImage, factor: factor)
            zommedImages.append(zommedImage)
        }
        
        return zommedImages
    }
    
    private func zoom(cgImage: CGImage, factor: CGFloat) -> CGImage {
        guard factor > 1 else { return cgImage }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let initialRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
        
        // Inset based on zoom factor
        let dx = imageSize.width * (1 - (1 / factor)) / 2
        let dy = imageSize.height * (1 - (1 / factor)) / 2
        let zoomedRect = initialRect.insetBy(dx: dx, dy: dy)
        
        return cgImage.cropping(to: zoomedRect) ?? cgImage
    }
    
    private func fit(cgImage: CGImage, to targetSize: CGSize) -> CGImage {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Calculate the aspect ratios and scale factor
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scaleFactor = min(widthRatio, heightRatio)

        // Construct the scaled rect
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        let offsetX = (targetSize.width - scaledWidth) / 2.0 // Center horizontally
        let offsetY = (targetSize.height - scaledHeight) / 2.0 // Center vertically
        let scaledRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        
        // Use a scale of 1 so the pixels match the target size
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let fitImage = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: scaledRect)
        }
        
        return fitImage.cgImage ?? cgImage
    }
}
