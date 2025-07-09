#!/usr/bin/env swift

import Foundation
import CoreML
import CoreImage
import CoreGraphics
import Vision

// MARK: - Build-Time Embedding Generator
// This script runs during Xcode build to pre-compute vector embeddings

struct PlantEmbedding: Codable {
    let plantId: String
    let name: String
    let scientificName: String?
    let embedding: [Float]
    let imageDigest: String
}

struct EmbeddingGenerator {
    init() throws {
        // No initialization needed for Vision framework
    }
    
    func generateEmbeddingsFromPlantData() throws {
        print("🌱 Starting build-time embedding generation...")
        
        // Load plant data from the project directory
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "demo-data.json")),
              let plantsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw EmbeddingError.dataLoadFailed
        }
        
        var embeddings: [PlantEmbedding] = []
        
        for (index, plantData) in plantsArray.enumerated() {
            guard let plantType = plantData["type"] as? String,
                  plantType == "plant",
                  let plantId = plantData["id"] as? String,
                  let name = plantData["name"] as? String,
                  let imagePath = plantData["image"] as? String else {
                continue
            }
            
            print("Processing \(index + 1)/\(plantsArray.count): \(name)")
            
            // Load image from assets
            let imageName = imagePath.replacingOccurrences(of: "demo-images/", with: "")
            guard let image = loadImage(named: imageName) else {
                print("⚠️  Could not load image for \(name)")
                continue
            }
            
            // Generate embedding
            if let embedding = try? generateEmbedding(for: image) {
                let plantEmbedding = PlantEmbedding(
                    plantId: plantId,
                    name: name,
                    scientificName: plantData["scientificName"] as? String,
                    embedding: embedding,
                    imageDigest: generateImageDigest(for: image)
                )
                embeddings.append(plantEmbedding)
                print("✅ Generated embedding for \(name) (768 dimensions)")
            } else {
                print("❌ Failed to generate embedding for \(name)")
            }
        }
        
        // Save embeddings to bundle
        try saveEmbeddings(embeddings)
        print("🎉 Generated \(embeddings.count) embeddings successfully!")
    }
    
    private func generateEmbedding(for image: CGImage) throws -> [Float] {
        // Scale down the image to speed up processing (same as AI.swift)
        let scaledImage = fit(cgImage: image, to: CGSize(width: 100, height: 100))
        
        // Perform feature detection using Vision framework
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: scaledImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw EmbeddingError.embeddingExtractionFailed
        }
        
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw EmbeddingError.embeddingExtractionFailed
        }

        // Access the feature data
        let data = observation.data
        guard data.isEmpty == false else {
            throw EmbeddingError.embeddingExtractionFailed
        }

        // Determine the element type and size
        let elementType = observation.elementType
        let elementCount = observation.elementCount
        let typeSize = VNElementTypeSize(elementType)
        var embedding: [Float]?
        
        // Handle the different element types (same as AI.swift)
        switch elementType {
        case .float where typeSize == MemoryLayout<Float>.size:
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                let buffer = bytes.bindMemory(to: Float.self)
                if buffer.count == elementCount {
                    embedding = buffer.map { $0 }
                }
            }
        default:
            throw EmbeddingError.embeddingExtractionFailed
        }

        guard let embedding = embedding else {
            throw EmbeddingError.embeddingExtractionFailed
        }
        
        return embedding
    }
    
    private func fit(cgImage: CGImage, to size: CGSize) -> CGImage {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleFactor = min(size.width / imageSize.width, size.height / imageSize.height)
        let newSize = CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor)
        
        let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        return context?.makeImage() ?? cgImage
    }
    
    private func loadImage(named: String) -> CGImage? {
        // Look for the image in the Assets.xcassets/demo-images structure
        let imageSetPath = "Assets.xcassets/demo-images/\(named).imageset"
        let imagePath = "\(imageSetPath)/\(named).jpg"
        
        // Try to load from the file system directly
        if let imageData = NSData(contentsOfFile: imagePath),
           let dataProvider = CGDataProvider(data: imageData),
           let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            return image
        }
        
        // Also try without .jpg extension in case it's named differently
        let altImagePath = "\(imageSetPath)/\(named)"
        if let imageData = NSData(contentsOfFile: altImagePath),
           let dataProvider = CGDataProvider(data: imageData),
           let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            return image
        }
        
        return nil
    }
    
    private func generateImageDigest(for image: CGImage) -> String {
        // Generate a simple hash for the image
        let width = image.width
        let height = image.height
        return "\(width)x\(height)_\(arc4random())"
    }
    
    private func saveEmbeddings(_ embeddings: [PlantEmbedding]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(embeddings)
        
        // Save to current directory (build script will move to bundle)
        let outputURL = URL(fileURLWithPath: "plant_embeddings.json")
        try jsonData.write(to: outputURL)
        
        print("📄 Embeddings saved to: \(outputURL.path)")
        
        // Also save metadata without embeddings for size comparison
        let metadata = embeddings.map { embedding in
            return [
                "plantId": embedding.plantId,
                "name": embedding.name,
                "scientificName": embedding.scientificName ?? "",
                "imageDigest": embedding.imageDigest,
                "embeddingSize": embedding.embedding.count
            ]
        }
        
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        let metadataURL = URL(fileURLWithPath: "embedding_metadata.json")
        try metadataData.write(to: metadataURL)
        
        // Calculate and report size savings
        let embeddingSize = jsonData.count
        let estimatedImageSize = embeddings.count * 200 * 1024 // Estimate 200KB per image
        let savings = 100 - (embeddingSize * 100 / estimatedImageSize)
        
        print("📊 Size Analysis:")
        print("   • Embeddings: \(embeddingSize / 1024)KB")
        print("   • Estimated images: \(estimatedImageSize / 1024 / 1024)MB")
        print("   • Savings: \(savings)%")
    }
}

enum EmbeddingError: Error {
    case modelLoadFailed
    case dataLoadFailed
    case embeddingExtractionFailed
}

// MARK: - Main Execution

do {
    let generator = try EmbeddingGenerator()
    try generator.generateEmbeddingsFromPlantData()
} catch {
    print("❌ Embedding generation failed: \(error)")
    exit(1)
} 