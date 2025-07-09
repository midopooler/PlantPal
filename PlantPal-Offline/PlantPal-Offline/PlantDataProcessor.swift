//
//  PlantDataProcessor.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Combine
import CouchbaseLiteSwift

class PlantDataProcessor: ObservableObject {
    static let shared = PlantDataProcessor()
    
    struct ProcessingProgress {
        let currentStep: String
        let currentItem: Int
        let totalItems: Int
        let message: String
        
        var percentage: Float {
            guard totalItems > 0 else { return 0.0 }
            return Float(currentItem) / Float(totalItems)
        }
    }
    
    @Published var processingProgress = ProcessingProgress(
        currentStep: "Initializing",
        currentItem: 0,
        totalItems: 48,
        message: "Processing..."
    )
    
    @Published var isProcessingComplete = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func startProcessing() {
        guard !isProcessingComplete else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Initialize the BuildTimeEmbeddingLoader to load pre-computed embeddings
            BuildTimeEmbeddingLoader.shared.processPlantData()
            BuildTimeEmbeddingLoader.shared.printPerformanceMetrics()
            
            // Use the regular processing but it will be much faster now
            self?.processPlantData()
        }
    }
    
    private func processPlantData() {
        updateProgress("Processing", 0, "Processing...")
        
        // Enable the vector search extension
        try! CouchbaseLiteSwift.Extension.enableVectorSearch()
        
        // Load demo data from JSON file
        guard let url = Bundle.main.url(forResource: "demo-data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            print("Failed to load demo data from JSON file")
            markComplete()
            return
        }
        
        let demoData = jsonArray
        updateProgress("Processing", 0, "Processing...")
        
        // Get or create demo database
        let database = try! CouchbaseLiteSwift.Database(name: "demo")
        let collection = try! database.defaultCollection()
        
        // Clear existing data if any
        if collection.count > 0 {
            updateProgress("Processing", 0, "Processing...")
            try! database.delete()
            let newDatabase = try! CouchbaseLiteSwift.Database(name: "demo")
            let newCollection = try! newDatabase.defaultCollection()
            setupIndices(for: newCollection)
            processItems(demoData, in: newCollection)
        } else {
            setupIndices(for: collection)
            processItems(demoData, in: collection)
        }
    }
    
    private func setupIndices(for collection: CouchbaseLiteSwift.Collection) {
        updateProgress("Processing", 0, "Processing...")
        
        // Initialize the value index on the "name" field for fast sorting
        let nameIndex = ValueIndexConfiguration(["name"])
        try! collection.createIndex(withName: "NameIndex", config: nameIndex)
        
        // Initialize the full-text search index on the "name" and "category" fields
        let ftsIndex = FullTextIndexConfiguration(["name", "category"])
        try! collection.createIndex(withName: "NameAndCategoryFullTextIndex", config: ftsIndex)
        
        print("🔍 Database indexes created (optimized for pre-computed embeddings)")
    }
    
    private func processItems(_ demoData: [[String: Any]], in collection: CouchbaseLiteSwift.Collection) {
        let batchSize = 10
        let totalBatches = (demoData.count + batchSize - 1) / batchSize
        
        updateProgress("Processing", 0, "Processing...")
        
        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, demoData.count)
            let batch = Array(demoData[startIndex..<endIndex])
            
            updateProgress("Processing", startIndex, "Processing...")
            
            // Process each item in the batch
            for (itemIndex, var demoItemData) in batch.enumerated() {
                let globalIndex = startIndex + itemIndex
                updateProgress("Processing", globalIndex, "Processing...")
                
                // Create a document
                let id = demoItemData.removeValue(forKey: "id") as? String
                let document = MutableDocument(id: id, data: demoItemData)
                
                // For plants, we now use pre-computed embeddings instead of images
                if let plantType = demoItemData["type"] as? String, plantType == "plant" {
                    // Remove the image field since we use pre-computed embeddings
                    document.removeValue(forKey: "image")
                    
                    // Add a reference to indicate this uses pre-computed embeddings
                    document["usesPrecomputedEmbedding"].boolean = true
                    
                    print("✅ Saved plant data for \(document["name"].string ?? "unknown") (using pre-computed embedding)")
                } else {
                    // For non-plant items, still try to load images if they exist
                    if let imageName = document["image"].string {
                        if let image = UIImage(named: "\(imageName)"),
                           let pngData = image.pngData() {
                            document["image"].blob = Blob(contentType: "image/png", data: pngData)
                        } else {
                            print("Warning: Could not load image '\(imageName)'")
                        }
                    }
                    
                    // Convert face image if present
                    if let imageName = document["face"].string {
                        if let image = UIImage(named: imageName),
                           let pngData = image.pngData() {
                            document["face"].blob = Blob(contentType: "image/png", data: pngData)
                        } else {
                            print("Warning: Could not load face image '\(imageName)'")
                        }
                    }
                }
                
                do {
                    try collection.save(document: document)
                } catch {
                    print("Error saving document \(id ?? "unknown"): \(error.localizedDescription)")
                }
            }
            
            // Small delay between batches
            if batchIndex < totalBatches - 1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        // Skip vector indexing for plants since we use pre-computed embeddings
        print("🎉 Plant data saved successfully with pre-computed embeddings!")
        markComplete()
    }

    
    private func updateProgress(_ step: String, _ current: Int, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.processingProgress = ProcessingProgress(
                currentStep: step,
                currentItem: current,
                totalItems: 48,
                message: message
            )
        }
    }
    
    private func markComplete() {
        DispatchQueue.main.async { [weak self] in
            self?.processingProgress = ProcessingProgress(
                currentStep: "Complete",
                currentItem: 48,
                totalItems: 48,
                message: "Ready!"
            )
            self?.isProcessingComplete = true
        }
    }
} 