//
//  MobileCLIPWrapper.swift
//  PlantPal-Offline
//
//  Created by Assistant on 01/08/25.
//

import UIKit
import CoreML

class MobileCLIPWrapper {
    static let shared = MobileCLIPWrapper()
    
    private var imageModel: MLModel?
    private let modelName = "mobileclip_s1_image" // Using S1 for better accuracy
    
    private init() {
        loadModel()
    }
    
    private func loadModel() {
        // Debug: Print bundle path and contents
        if let bundlePath = Bundle.main.resourcePath {
            print("📦 Bundle path: \(bundlePath)")
            
            // Check if models directory exists
            let modelsPath = bundlePath + "/models"
            if FileManager.default.fileExists(atPath: modelsPath) {
                print("✅ Models directory exists at: \(modelsPath)")
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: modelsPath)
                    print("📁 Models directory contents: \(contents)")
                } catch {
                    print("❌ Failed to read models directory: \(error)")
                }
            } else {
                print("❌ Models directory does not exist at: \(modelsPath)")
                
                // Check what's in the bundle root
                do {
                    let rootContents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                    print("📁 Bundle root contents: \(rootContents)")
                } catch {
                    print("❌ Failed to read bundle root: \(error)")
                }
            }
        }
        
        // Look for compiled .mlmodelc in bundle root (Xcode auto-compiles .mlpackage files)
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("❌ Could not find compiled MobileCLIP model: \(modelName).mlmodelc in bundle root")
            
            // Fallback: Try .mlpackage in case it wasn't compiled
            if let fallbackURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") {
                print("🔄 Found uncompiled model, will compile: \(fallbackURL)")
                loadModelFromURL(fallbackURL)
                return
            }
            
            return
        }
        
        print("✅ Found model at: \(modelURL)")
        loadModelFromURL(modelURL)
    }
    
    private func loadModelFromURL(_ modelURL: URL) {
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all // Use Neural Engine when available
            
            // Check if this is already a compiled model (.mlmodelc)
            if modelURL.pathExtension == "mlmodelc" {
                imageModel = try MLModel(contentsOf: modelURL, configuration: configuration)
                print("✅ Loaded compiled MobileCLIP model: \(modelName)")
            } else {
                // For .mlpackage files, compile first
                print("🔨 Compiling .mlpackage model...")
                let compiledURL = try MLModel.compileModel(at: modelURL)
                imageModel = try MLModel(contentsOf: compiledURL, configuration: configuration)
                print("✅ Loaded and compiled MobileCLIP model: \(modelName)")
            }
            
        } catch {
            print("❌ Failed to load MobileCLIP model: \(error)")
        }
    }
    
    // MARK: - Public Interface (matches AI.swift Vision interface)
    
    func embedding(for cgImage: CGImage) -> [Float]? {
        guard let model = imageModel else {
            print("❌ MobileCLIP model not loaded")
            return nil
        }
        
        // Preprocess image for MobileCLIP (224x224, normalized)
        guard let processedImage = preprocessImage(cgImage) else {
            print("❌ Failed to preprocess image for MobileCLIP")
            return nil
        }
        
        do {
            // Create input for the model
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": processedImage])
            
            // Perform inference
            let output = try model.prediction(from: input)
            
            // Extract embedding from output
            guard let embeddingArray = output.featureValue(for: "final_emb_1")?.multiArrayValue else {
                print("❌ Could not extract embedding from MobileCLIP output")
                return nil
            }
            
            // Convert MLMultiArray to [Float]
            let embedding = convertMLMultiArrayToFloat(embeddingArray)
            
            if embedding.count != 512 {
                print("⚠️ Unexpected embedding dimension: \(embedding.count), expected 512")
            }
            
            return embedding
            
        } catch {
            print("❌ MobileCLIP inference failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Image Preprocessing
    
    private func preprocessImage(_ cgImage: CGImage) -> MLFeatureValue? {
        // MobileCLIP expects 256x256 RGB image, normalized
        let targetSize = CGSize(width: 256, height: 256)
        
        // Resize image to 256x256
        guard let resizedImage = resizeImage(cgImage, to: targetSize) else {
            return nil
        }
        
        // Convert to MLMultiArray with proper normalization
        guard let pixelBuffer = createPixelBuffer(from: resizedImage) else {
            return nil
        }
        
        return MLFeatureValue(pixelBuffer: pixelBuffer)
    }
    
    private func resizeImage(_ cgImage: CGImage, to size: CGSize) -> CGImage? {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        let image = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        }
        
        return image.cgImage
    }
    
    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
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
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    // MARK: - Utilities
    
    private func convertMLMultiArrayToFloat(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        let dataPointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: dataPointer, count: count))
    }
    
    // MARK: - For Build Scripts (Static Methods)
    
    static func generateEmbedding(for cgImage: CGImage) throws -> [Float] {
        guard let embedding = shared.embedding(for: cgImage) else {
            throw MobileCLIPError.embeddingGenerationFailed
        }
        return embedding
    }
    
    static func fit(cgImage: CGImage, to targetSize: CGSize) -> CGImage {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Calculate the aspect ratios and scale factor
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scaleFactor = min(widthRatio, heightRatio)

        // Construct the scaled rect
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        let offsetX = (targetSize.width - scaledWidth) / 2.0
        let offsetY = (targetSize.height - scaledHeight) / 2.0
        let scaledRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let fitImage = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: scaledRect)
        }
        
        return fitImage.cgImage ?? cgImage
    }
}

// MARK: - Error Types

enum MobileCLIPError: Error {
    case modelNotLoaded
    case embeddingGenerationFailed
    case invalidImageFormat
    case preprocessingFailed
} 