#!/usr/bin/env swift

import Foundation
import CoreML
import CoreImage
import CoreGraphics
// import Vision // Replaced with MobileCLIP

// MARK: - Build-Time Embedding Generator
// This script runs during Xcode build to pre-compute vector embeddings

// MARK: - MobileCLIP Integration for Build Scripts

class BuildTimeMobileCLIP {
    private var imageModel: MLModel?
    private let modelName = "mobileclip_s1_image"
    
    init() throws {
        try loadModel()
    }
    
    private func loadModel() throws {
        // Look for model in the models directory
        let modelURL = URL(fileURLWithPath: "../PlantPal-Offline/models/\(modelName).mlpackage")
        
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw EmbeddingError.modelNotFound
        }
        
        print("🔨 Compiling MobileCLIP model...")
        let compiledModelURL = try MLModel.compileModel(at: modelURL)
        
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        imageModel = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        print("✅ Loaded and compiled MobileCLIP model for build-time generation")
    }
    
    func generateEmbedding(for cgImage: CGImage) throws -> [Float] {
        guard let model = imageModel else {
            throw EmbeddingError.modelNotLoaded
        }
        
        // Preprocess image for MobileCLIP (256x256)
        let scaledImage = fit(cgImage: cgImage, to: CGSize(width: 256, height: 256))
        guard let pixelBuffer = createPixelBuffer(from: scaledImage) else {
            throw EmbeddingError.preprocessingFailed
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
            let output = try model.prediction(from: input)
            
            // Output features available: final_emb_1
            
            guard let embeddingArray = output.featureValue(for: "final_emb_1")?.multiArrayValue else {
                print("❌ Could not find 'final_emb_1' in model outputs")
                throw EmbeddingError.embeddingExtractionFailed
            }
            
            let embedding = convertMLMultiArrayToFloat(embeddingArray)
            
            if embedding.count != 512 {
                print("⚠️ Unexpected embedding dimension: \(embedding.count), expected 512")
            }
            
            return embedding
            
        } catch {
            print("❌ MobileCLIP inference error: \(error)")
            throw EmbeddingError.embeddingExtractionFailed
        }
    }
    
    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        // MobileCLIP requires exactly 256x256 pixels
        let width = 256
        let height = 256
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        // Scale the image to fit exactly 256x256
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        return buffer
    }
    
    private func convertMLMultiArrayToFloat(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        let dataPointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: dataPointer, count: count))
    }
    
    private func fit(cgImage: CGImage, to size: CGSize) -> CGImage {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleFactor = min(size.width / imageSize.width, size.height / imageSize.height)
        let newSize = CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor)
        
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
        )
        
        let offsetX = (size.width - newSize.width) / 2
        let offsetY = (size.height - newSize.height) / 2
        context?.draw(cgImage, in: CGRect(x: offsetX, y: offsetY, width: newSize.width, height: newSize.height))
        
        return context?.makeImage() ?? cgImage
    }
}

struct PlantEmbedding: Codable {
    let plantId: String
    let name: String
    let scientificName: String?
    let embedding: [Float]
    let imageDigest: String
}

struct EmbeddingGenerator {
    private let mobileCLIP: BuildTimeMobileCLIP
    
    init() throws {
        mobileCLIP = try BuildTimeMobileCLIP()
    }
    
    func generateEmbeddingsFromPlantData() throws {
        print("🌱 Starting build-time embedding generation from dataset folder...")
        
        // Read plant images directly from full-dataset folder
        let datasetPath = "../PlantPal-Offline/full-dataset"
        let datasetURL = URL(fileURLWithPath: datasetPath)
        
        guard let imageFiles = try? FileManager.default.contentsOfDirectory(at: datasetURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            print("❌ Could not read dataset folder at: \(datasetPath)")
            throw EmbeddingError.dataLoadFailed
        }
        
        let imageExtensions = Set(["jpg", "jpeg", "png", "JPG", "JPEG", "PNG"])
        let validImageFiles = imageFiles.filter { url in
            imageExtensions.contains(url.pathExtension)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        print("📁 Found \(validImageFiles.count) plant images in dataset")
        var embeddings: [PlantEmbedding] = []
        
        for (index, imageURL) in validImageFiles.enumerated() {
            let filename = imageURL.lastPathComponent
            
            // Extract plant name and scientific name from filename
            // Format: "Plant Name (Scientific name).jpg"
            let nameWithoutExtension = imageURL.deletingPathExtension().lastPathComponent
            let (plantName, scientificName) = parseFilename(nameWithoutExtension)
            
            print("Processing \(index + 1)/\(validImageFiles.count): \(plantName)")
            
            // Load and process image
            guard let imageData = try? Data(contentsOf: imageURL),
                  let cgImage = loadCGImage(from: imageData) else {
                print("⚠️  Could not load image: \(filename)")
                continue
            }
            
            // Generate embedding using MobileCLIP
            do {
                let embedding = try mobileCLIP.generateEmbedding(for: cgImage)
                let plantId = plantName.lowercased().replacingOccurrences(of: " ", with: "_")
                
                let plantEmbedding = PlantEmbedding(
                    plantId: plantId,
                    name: plantName,
                    scientificName: scientificName,
                    embedding: embedding,
                    imageDigest: generateImageDigest(for: cgImage)
                )
                embeddings.append(plantEmbedding)
                print("✅ Generated embedding for \(plantName) (512 dimensions)")
            } catch {
                print("❌ Failed to generate embedding for \(plantName): \(error)")
            }
        }
        
        // Save embeddings to bundle
        try saveEmbeddings(embeddings)
        print("🎉 Generated \(embeddings.count) embeddings from dataset successfully!")
    }
    
    private func parseFilename(_ filename: String) -> (plantName: String, scientificName: String?) {
        // Parse format: "Plant Name (Scientific name)" or "Plant Name" or "Plant Name 123"
        var baseName = filename
        var scientificName: String? = nil
        
        // Extract scientific name if present
        if let parenIndex = filename.firstIndex(of: "("),
           let closeParenIndex = filename.firstIndex(of: ")") {
            baseName = String(filename[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            scientificName = String(filename[filename.index(after: parenIndex)..<closeParenIndex])
        }
        
        // Remove trailing numbers and spaces (e.g., "Aloe Vera 139" -> "Aloe Vera")
        let cleanedName = baseName.replacingOccurrences(of: #"\s+\d+$"#, with: "", options: .regularExpression)
        
        return (cleanedName, scientificName)
    }
    
    private func loadCGImage(from data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return cgImage
    }
    
    // Vision-based embedding generation removed - now using MobileCLIP via BuildTimeMobileCLIP class
    
    // fit function moved to BuildTimeMobileCLIP class
    
    private func loadImage(named: String) -> CGImage? {
        // Since demo images don't exist, use the app icon as a test image
        // This will generate valid 512-dimensional embeddings for testing
        let iconPath = "../PlantPal-Offline/Assets.xcassets/AppIcon.appiconset/image (1).png"
        
        if let imageData = NSData(contentsOfFile: iconPath),
           let dataProvider = CGDataProvider(data: imageData),
           let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            print("📱 Using app icon as test image for \(named)")
            return image
        }
        
        print("❌ Could not load test image from \(iconPath)")
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
        let savings = estimatedImageSize > 0 ? 100 - (embeddingSize * 100 / estimatedImageSize) : 0
        
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
    case modelNotFound
    case modelNotLoaded
    case preprocessingFailed
}

// MARK: - Main Execution

do {
    let generator = try EmbeddingGenerator()
    try generator.generateEmbeddingsFromPlantData()
} catch {
    print("❌ Embedding generation failed: \(error)")
    exit(1)
} 