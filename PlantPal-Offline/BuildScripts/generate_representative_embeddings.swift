#!/usr/bin/env swift

//
//  generate_representative_embeddings.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import Foundation
// import Vision // Replaced with MobileCLIP
import CoreImage
import CoreML

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
            
            guard let embeddingArray = output.featureValue(for: "final_emb_1")?.multiArrayValue else {
                throw EmbeddingError.embeddingExtractionFailed
            }
            
            let embedding = convertMLMultiArrayToFloat(embeddingArray)
            
            if embedding.count != 512 {
                print("⚠️ Unexpected embedding dimension: \(embedding.count), expected 512")
            }
            
            return embedding
            
        } catch {
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

enum EmbeddingError: Error {
    case modelNotFound
    case modelNotLoaded
    case preprocessingFailed
    case embeddingExtractionFailed
    case dataLoadFailed
}

// MARK: - Data Structures

struct PlantImageData {
    let plantId: String
    let plantName: String
    let imagePath: String
    let embedding: [Float]
    let confidence: Float
}

struct RepresentativeEmbedding {
    let id: String
    let embedding: [Float]
    let confidence: Float
    let source: String
}

struct PlantRepresentatives {
    let plantId: String
    let name: String
    let scientificName: String?
    let representatives: [RepresentativeEmbedding]
}

// MARK: - Configuration

struct Config {
    static let inputDataPath = "dataset/"  // Path to 15,000 images organized by plant folders
    static let outputPath = "plant_embeddings_representative.json"
    static let representativesPerPlant = 5
    static let batchSize = 100
    static let maxImagesPerPlant = 500  // Limit processing if a plant has too many images
}

// MARK: - Main Processing Class

class RepresentativeEmbeddingGenerator {
    private let mobileCLIP: BuildTimeMobileCLIP
    private var processedCount = 0
    private var totalCount = 0
    
    init() throws {
        mobileCLIP = try BuildTimeMobileCLIP()
    }
    
    func generateRepresentativeEmbeddings() {
        print("🚀 Starting representative embedding generation...")
        
        // Step 1: Discover all plant folders and images
        let plantFolders = discoverPlantFolders()
        print("📁 Found \(plantFolders.count) plant categories")
        
        // Step 2: Process each plant category
        var allRepresentatives: [PlantRepresentatives] = []
        
        for (index, folder) in plantFolders.enumerated() {
            print("\n🌱 Processing \(folder.name) (\(index + 1)/\(plantFolders.count))")
            
            if let representatives = processPlantFolder(folder) {
                allRepresentatives.append(representatives)
                print("✅ Generated \(representatives.representatives.count) representatives for \(folder.name)")
            } else {
                print("❌ Failed to process \(folder.name)")
            }
        }
        
        // Step 3: Save representative embeddings
        saveRepresentativeEmbeddings(allRepresentatives)
        
        // Step 4: Generate summary
        generateSummary(allRepresentatives)
    }
    
    private func discoverPlantFolders() -> [PlantFolder] {
        let fileManager = FileManager.default
        let dataPath = URL(fileURLWithPath: Config.inputDataPath)
        
        var plantFolders: [PlantFolder] = []
        
        do {
            let folderContents = try fileManager.contentsOfDirectory(at: dataPath, includingPropertiesForKeys: nil)
            
            for folderURL in folderContents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let folderName = folderURL.lastPathComponent
                    let imageFiles = discoverImageFiles(in: folderURL)
                    
                    if !imageFiles.isEmpty {
                        let plantFolder = PlantFolder(
                            name: folderName,
                            path: folderURL.path,
                            imageFiles: imageFiles,
                            plantId: generatePlantId(from: folderName)
                        )
                        plantFolders.append(plantFolder)
                    }
                }
            }
        } catch {
            print("❌ Error discovering plant folders: \(error)")
        }
        
        return plantFolders.sorted { $0.name < $1.name }
    }
    
    private func discoverImageFiles(in folderURL: URL) -> [String] {
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif"]
        
        var imageFiles: [String] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            
            for file in files {
                let fileExtension = file.pathExtension.lowercased()
                if imageExtensions.contains(fileExtension) {
                    imageFiles.append(file.path)
                }
            }
        } catch {
            print("❌ Error discovering image files in \(folderURL.path): \(error)")
        }
        
        return imageFiles
    }
    
    private func processPlantFolder(_ folder: PlantFolder) -> PlantRepresentatives? {
        // Step 1: Limit images if too many
        let imagesToProcess = Array(folder.imageFiles.prefix(Config.maxImagesPerPlant))
        print("📸 Processing \(imagesToProcess.count) images for \(folder.name)")
        
        // Step 2: Generate embeddings for all images in batches
        var allEmbeddings: [PlantImageData] = []
        let batches = imagesToProcess.chunked(into: Config.batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            print("⚡ Processing batch \(batchIndex + 1)/\(batches.count)")
            
            let batchEmbeddings = processBatch(batch, plantId: folder.plantId, plantName: folder.name)
            allEmbeddings.append(contentsOf: batchEmbeddings)
            
            // Small delay to prevent overwhelming the system
            usleep(100000) // 0.1 seconds
        }
        
        guard !allEmbeddings.isEmpty else {
            print("❌ No valid embeddings generated for \(folder.name)")
            return nil
        }
        
        // Step 3: Select representative embeddings
        let representatives = selectRepresentatives(from: allEmbeddings)
        
        return PlantRepresentatives(
            plantId: folder.plantId,
            name: folder.name,
            scientificName: extractScientificName(from: folder.name),
            representatives: representatives
        )
    }
    
    private func processBatch(_ imagePaths: [String], plantId: String, plantName: String) -> [PlantImageData] {
        var embeddings: [PlantImageData] = []
        
        for imagePath in imagePaths {
            if let embedding = generateEmbedding(for: imagePath) {
                let imageData = PlantImageData(
                    plantId: plantId,
                    plantName: plantName,
                    imagePath: imagePath,
                    embedding: embedding,
                    confidence: 1.0 // Will be calculated later
                )
                embeddings.append(imageData)
                processedCount += 1
            }
        }
        
        return embeddings
    }
    
    private func generateEmbedding(for imagePath: String) -> [Float]? {
        guard let image = loadImage(from: imagePath) else { return nil }
        
        do {
            return try mobileCLIP.generateEmbedding(for: image)
        } catch {
            print("❌ Error generating MobileCLIP embedding for \(imagePath): \(error)")
            return nil
        }
    }
    
    private func selectRepresentatives(from embeddings: [PlantImageData]) -> [RepresentativeEmbedding] {
        guard embeddings.count > 0 else { return [] }
        
        // If we have fewer images than desired representatives, return all
        if embeddings.count <= Config.representativesPerPlant {
            return embeddings.enumerated().map { index, embedding in
                RepresentativeEmbedding(
                    id: "rep_\(index)",
                    embedding: embedding.embedding,
                    confidence: 1.0,
                    source: URL(fileURLWithPath: embedding.imagePath).lastPathComponent
                )
            }
        }
        
        // Use K-means clustering to find representative embeddings
        let clusters = performKMeansClustering(embeddings: embeddings, k: Config.representativesPerPlant)
        
        // Select the embedding closest to each cluster centroid
        var representatives: [RepresentativeEmbedding] = []
        
        for (clusterIndex, cluster) in clusters.enumerated() {
            if let bestRepresentative = findBestRepresentative(in: cluster) {
                let representative = RepresentativeEmbedding(
                    id: "rep_\(clusterIndex)",
                    embedding: bestRepresentative.embedding,
                    confidence: calculateConfidence(for: bestRepresentative, in: cluster),
                    source: URL(fileURLWithPath: bestRepresentative.imagePath).lastPathComponent
                )
                representatives.append(representative)
            }
        }
        
        return representatives.sorted { $0.confidence > $1.confidence }
    }
    
    private func performKMeansClustering(embeddings: [PlantImageData], k: Int) -> [[PlantImageData]] {
        // Simple K-means implementation
        let maxIterations = 10
        var centroids: [[Float]] = []
        var clusters: [[PlantImageData]] = Array(repeating: [], count: k)
        
        // Initialize centroids randomly
        for _ in 0..<k {
            centroids.append(embeddings.randomElement()!.embedding)
        }
        
        for _ in 0..<maxIterations {
            // Clear clusters
            clusters = Array(repeating: [], count: k)
            
            // Assign each embedding to nearest centroid
            for embedding in embeddings {
                let nearestCentroidIndex = findNearestCentroid(embedding: embedding.embedding, centroids: centroids)
                clusters[nearestCentroidIndex].append(embedding)
            }
            
            // Update centroids
            for i in 0..<k {
                if !clusters[i].isEmpty {
                    centroids[i] = calculateCentroid(for: clusters[i])
                }
            }
        }
        
        return clusters.filter { !$0.isEmpty }
    }
    
    private func findNearestCentroid(embedding: [Float], centroids: [[Float]]) -> Int {
        var minDistance = Float.greatestFiniteMagnitude
        var nearestIndex = 0
        
        for (index, centroid) in centroids.enumerated() {
            let distance = calculateEuclideanDistance(embedding, centroid)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        return nearestIndex
    }
    
    private func calculateCentroid(for cluster: [PlantImageData]) -> [Float] {
        let embeddingSize = cluster.first?.embedding.count ?? 0
        var centroid = Array(repeating: Float(0), count: embeddingSize)
        
        for embedding in cluster {
            for i in 0..<embeddingSize {
                centroid[i] += embedding.embedding[i]
            }
        }
        
        let clusterSize = Float(cluster.count)
        for i in 0..<embeddingSize {
            centroid[i] /= clusterSize
        }
        
        return centroid
    }
    
    private func findBestRepresentative(in cluster: [PlantImageData]) -> PlantImageData? {
        guard !cluster.isEmpty else { return nil }
        
        let centroid = calculateCentroid(for: cluster)
        var bestRepresentative: PlantImageData?
        var minDistance = Float.greatestFiniteMagnitude
        
        for embedding in cluster {
            let distance = calculateEuclideanDistance(embedding.embedding, centroid)
            if distance < minDistance {
                minDistance = distance
                bestRepresentative = embedding
            }
        }
        
        return bestRepresentative
    }
    
    private func calculateConfidence(for representative: PlantImageData, in cluster: [PlantImageData]) -> Float {
        // Calculate confidence based on how central the representative is to the cluster
        let centroid = calculateCentroid(for: cluster)
        let distance = calculateEuclideanDistance(representative.embedding, centroid)
        
        // Convert distance to confidence (closer = higher confidence)
        return max(0.0, 1.0 - (distance / 2.0))
    }
    
    private func calculateEuclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return Float.greatestFiniteMagnitude }
        
        let squaredDifferences = zip(a, b).map { ($0 - $1) * ($0 - $1) }
        return sqrt(squaredDifferences.reduce(0, +))
    }
    
    private func saveRepresentativeEmbeddings(_ representatives: [PlantRepresentatives]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(representatives)
            let outputURL = URL(fileURLWithPath: Config.outputPath)
            try data.write(to: outputURL)
            
            print("✅ Saved representative embeddings to \(Config.outputPath)")
            print("📊 File size: \(data.count / 1024)KB")
        } catch {
            print("❌ Error saving representative embeddings: \(error)")
        }
    }
    
    private func generateSummary(_ representatives: [PlantRepresentatives]) {
        let totalRepresentatives = representatives.reduce(0) { $0 + $1.representatives.count }
        let avgRepresentatives = totalRepresentatives / representatives.count
        
        print("""
        
        🎉 Representative Embedding Generation Complete!
        
        📊 Summary:
        • Plant categories: \(representatives.count)
        • Total representatives: \(totalRepresentatives)
        • Average per plant: \(avgRepresentatives)
        • Images processed: \(processedCount)
        • Output file: \(Config.outputPath)
        
        ⚡ Performance:
        • Reduced from 15,000 to \(totalRepresentatives) embeddings
        • Size reduction: \(100 - (totalRepresentatives * 100 / 15000))%
        • Expected file size: ~\(totalRepresentatives * 3)KB
        """)
    }
    
    // MARK: - Helper Methods
    
    private func loadImage(from path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        
        // Load as CIImage first, then convert to CGImage
        guard let ciImage = CIImage(contentsOf: url) else { return nil }
        
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
    
    private func generatePlantId(from folderName: String) -> String {
        // Convert folder name to plant ID
        let cleanName = folderName.replacingOccurrences(of: " ", with: "_")
        return "plant_\(cleanName.lowercased())"
    }
    
    private func extractScientificName(from folderName: String) -> String? {
        // Extract scientific name if it's in parentheses
        if let range = folderName.range(of: "\\((.+)\\)", options: .regularExpression) {
            return String(folderName[range]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        }
        return nil
    }
}

// MARK: - Supporting Types

struct PlantFolder {
    let name: String
    let path: String
    let imageFiles: [String]
    let plantId: String
}

// MARK: - Codable Extensions

extension PlantRepresentatives: Codable {}
extension RepresentativeEmbedding: Codable {}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Main Execution

do {
    let generator = try RepresentativeEmbeddingGenerator()
    generator.generateRepresentativeEmbeddings()
} catch {
    print("❌ Representative embedding generation failed: \(error)")
    exit(1)
} 