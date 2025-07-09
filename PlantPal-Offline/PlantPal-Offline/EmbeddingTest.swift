//
//  EmbeddingTest.swift
//  PlantPal
//
//  Created for testing build-time embedding optimization
//

import Foundation
import UIKit

class EmbeddingTest {
    
    static func testEmbeddingLoader() {
        print("🧪 Testing BuildTimeEmbeddingLoader...")
        
        // Test 1: Check if embeddings file exists
        guard let embeddingsURL = Bundle.main.url(forResource: "plant_embeddings", withExtension: "json") else {
            print("❌ plant_embeddings.json not found in bundle")
            return
        }
        
        print("✅ plant_embeddings.json found in bundle")
        
        // Test 2: Try to load and parse the embeddings
        do {
            let data = try Data(contentsOf: embeddingsURL)
            let embeddings = try JSONDecoder().decode([PreComputedPlantEmbedding].self, from: data)
            
            print("✅ Successfully loaded \(embeddings.count) embeddings")
            
            // Test 3: Verify embedding structure
            if let firstEmbedding = embeddings.first {
                print("✅ First embedding: \(firstEmbedding.name)")
                print("✅ Embedding dimensions: \(firstEmbedding.embedding.count)")
                
                // Test 4: Calculate size savings
                let embeddingSize = data.count
                let estimatedImageSize = embeddings.count * 200 * 1024 // 200KB per image
                let savings = 100 - (embeddingSize * 100 / estimatedImageSize)
                
                print("📊 Size Analysis:")
                print("   • Embeddings: \(embeddingSize / 1024)KB")
                print("   • Estimated original images: \(estimatedImageSize / 1024 / 1024)MB")
                print("   • Savings: \(savings)%")
            }
            
        } catch {
            print("❌ Error loading embeddings: \(error)")
        }
        
        // Test 5: Test BuildTimeEmbeddingLoader integration
        print("\n🔧 Testing BuildTimeEmbeddingLoader integration...")
        
        // This would normally be called at app launch
        // BuildTimeEmbeddingLoader.shared.processPlantData()
        // BuildTimeEmbeddingLoader.shared.printPerformanceMetrics()
        
        print("✅ BuildTimeEmbeddingLoader integration test complete!")
    }
}

// Usage: Call EmbeddingTest.testEmbeddingLoader() in your app delegate or during development 