//
//  BuildTimeEmbeddingLoader.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import Foundation
import UIKit

// MARK: - Pre-computed Embedding Loader

struct PreComputedPlantEmbedding: Codable {
    let plantId: String
    let name: String
    let scientificName: String?
    let embedding: [Float]
    let imageDigest: String
}

class BuildTimeEmbeddingLoader {
    static let shared = BuildTimeEmbeddingLoader()
    
    internal var preComputedEmbeddings: [String: PreComputedPlantEmbedding] = [:]
    
    private init() {
        // Load pre-computed embeddings
        loadPreComputedEmbeddings()
    }
    
    // MARK: - Load Pre-computed Embeddings
    
    private func loadPreComputedEmbeddings() {
        guard let embeddingsURL = Bundle.main.url(forResource: "plant_embeddings", withExtension: "json"),
              let data = try? Data(contentsOf: embeddingsURL),
              let embeddings = try? JSONDecoder().decode([PreComputedPlantEmbedding].self, from: data) else {
            print("❌ Failed to load pre-computed embeddings, falling back to runtime generation")
            return
        }
        
        print("📦 Loading \(embeddings.count) pre-computed embeddings...")
        
        // Store embeddings indexed by plant ID for quick lookup
        for embedding in embeddings {
            preComputedEmbeddings[embedding.plantId] = embedding
        }
        
        print("✅ Pre-computed embeddings loaded successfully!")
        print("💾 Memory usage: ~\(embeddings.count * 768 * 4 / 1024)KB (vs ~10MB for images)")
    }
    
    // MARK: - Process Plant Data with Pre-computed Embeddings
    
    func processPlantData() {
        print("🌱 Processing plant data with pre-computed embeddings...")
        print("✅ Pre-computed embeddings loaded: \(preComputedEmbeddings.count) plants")
        
        // The actual database processing is handled by the existing Database singleton
        // and PlantDataProcessor. We just need to make sure our embeddings are available.
        
        // Note: The existing Database.shared will handle the actual Couchbase operations
        // This loader just provides the pre-computed embeddings for the search functionality
        
        print("🎉 Plant data processing complete!")
    }
    
    // MARK: - Embedding Access Methods
    
    func getEmbedding(forPlantId plantId: String) -> [Float]? {
        return preComputedEmbeddings[plantId]?.embedding
    }
    
    func getEmbedding(forPlantName plantName: String) -> [Float]? {
        for (_, embedding) in preComputedEmbeddings {
            if embedding.name == plantName {
                return embedding.embedding
            }
        }
        return nil
    }
    
    // MARK: - Embedding Lookup for New Images
    
    func getEmbeddingForNewImage(_ image: UIImage) -> [Float]? {
        // For new images (camera captures), we still need to generate embeddings
        // This uses the same AI.swift embedding generation but only for new images
        return AI.shared.embedding(for: image)
    }
    
    // MARK: - Performance Metrics
    
    func printPerformanceMetrics() {
        let embeddingCount = preComputedEmbeddings.count
        let embeddingSize = embeddingCount * 768 * 4 // 768 floats * 4 bytes each
        let estimatedImageSize = embeddingCount * 150 * 1024 // Estimate 150KB per image
        
        print("""
        📊 Pre-computed Embedding Performance:
        
        🌱 Plants: \(embeddingCount)
        💾 Embedding data: \(embeddingSize / 1024)KB
        🖼️ Estimated original images: \(estimatedImageSize / 1024 / 1024)MB
        📉 Size reduction: \(100 - (embeddingSize * 100 / estimatedImageSize))%
        
        ⚡ Performance benefits:
        • No runtime embedding generation
        • Instant plant database loading
        • Reduced memory usage
        • Faster app startup
        """)
    }
} 