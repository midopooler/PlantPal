//
//  Database.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import CouchbaseLiteSwift
import Combine

class Database {
    static let shared = Database()
    
    private var database: CouchbaseLiteSwift.Database!
    private var collection: CouchbaseLiteSwift.Collection!
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupDatabase()
        endpoint = Settings.shared.endpoint
        startSync()
        
        // When the demo is enabled/disabled, update the database and sync
        Settings.shared.$isDemoEnabled
            .dropFirst()
            .sink { [weak self] isDemoEnabled in
                self?.stopSync()
                self?.setupDatabase(isDemoEnabled: isDemoEnabled)
                self?.startSync()
            }.store(in: &cancellables)
        
        // When the endpoint settings change, update the sync endpoint
        Settings.shared.$endpoint
            .dropFirst()
            .sink { [weak self] newEndpoint in
                self?.endpoint = newEndpoint
            }.store(in: &cancellables)
    }
    
    private func setupDatabase(isDemoEnabled: Bool = Settings.shared.isDemoEnabled) {
        var database: CouchbaseLiteSwift.Database
        var collection: CouchbaseLiteSwift.Collection
        
        // Enable the vector search extension
        try! CouchbaseLiteSwift.Extension.enableVectorSearch()
        
        if isDemoEnabled {
            // Setup the demo database (PlantDataProcessor handles the data loading)
            database = try! CouchbaseLiteSwift.Database(name: "demo")
            collection = try! database.defaultCollection()
        } else {
            database = try! CouchbaseLiteSwift.Database(name: "intelligence")
            collection = try! database.defaultCollection()
        }
        
        // Initialize the value index on the "name" field for fast sorting.
        let nameIndex = ValueIndexConfiguration(["name"])
        try! collection.createIndex(withName: "NameIndex", config: nameIndex)
        
        // Initialize the full-text search index on the "name" and "category" fields.
        let ftsIndex = FullTextIndexConfiguration(["name", "category"])
        try! collection.createIndex(withName: "NameAndCategoryFullTextIndex", config: ftsIndex)
        
        // Only create vector indexes for non-demo mode (plants use pre-computed embeddings)
        if !isDemoEnabled {
            // Initialize the vector index on the "image" field for image search.
            var imageVectorIndex = VectorIndexConfiguration(expression: "image", dimensions: 768, centroids: 2)
            imageVectorIndex.metric = .cosine
            imageVectorIndex.isLazy = true
            try! collection.createIndex(withName: "ImageVectorIndex", config: imageVectorIndex)
            
            print("🔍 Created vector indexes for general intelligence mode")
        } else {
            print("🌱 Skipping vector index creation - using pre-computed embeddings for plants")
        }
        
        setupAsyncIndexing(for: collection)
        
        self.database = database
        self.collection = collection
    }
    
    deinit {
        cancellables.removeAll()
        stopSync()
    }
    
    // MARK: - Search
    
    func search(image: UIImage) -> [Record] {
        // Perform plant search using image embeddings
        let embeddings = AI.shared.embeddings(for: image, attention: .zoom(factors: [1, 2]))
        for embedding in embeddings {
            let plantSearchResults = self.searchPlants(vector: embedding)
            if !plantSearchResults.isEmpty {
                return plantSearchResults
            }
        }
        return []
    }
    
    func search(string: String) -> [Record] {
        var searchString = string.trimmingCharacters(in: .whitespaces)
        if !searchString.hasSuffix("*") {
            searchString = searchString.appending("*")
        }
        
        // SQL for plants only
        let sql = """
            SELECT type, name, scientificName, price, location, wateringSchedule, careInstructions, characteristics
            FROM _
            WHERE type = "plant"
              AND MATCH(NameAndCategoryFullTextIndex, $search)
            ORDER BY RANK(NameAndCategoryFullTextIndex), name
        """
        
        do {
            // Create the query.
            let query = try collection.database.createQuery(sql)
            query.parameters = Parameters()
                .setString(searchString, forName: "search")
            
            // Execute the query and get the results.
            let results = try query.execute()
            
            // Enumerate through the query results.
            var records = [Record]()
            for result in results {
                if let name = result["name"].string,
                   let price = result["price"].number,
                   let location = result["location"].string,
                   let type = result["type"].string
                {
                    // Create Plant instance with detailed care information
                    let scientificName = result["scientificName"].string
                    
                    var wateringSchedule: Plant.WateringSchedule?
                    if let wateringDict = result["wateringSchedule"].dictionary {
                        wateringSchedule = Plant.WateringSchedule(
                            frequency: wateringDict["frequency"].string ?? "",
                            amount: wateringDict["amount"].string ?? "",
                            notes: wateringDict["notes"].string ?? ""
                        )
                    }
                    
                    var careInstructions: Plant.CareInstructions?
                    if let careDict = result["careInstructions"].dictionary {
                        careInstructions = Plant.CareInstructions(
                            light: careDict["light"].string ?? "",
                            temperature: careDict["temperature"].string ?? "",
                            humidity: careDict["humidity"].string ?? "",
                            fertilizer: careDict["fertilizer"].string ?? "",
                            pruning: careDict["pruning"].string ?? ""
                        )
                    }
                    
                    var characteristics: Plant.PlantCharacteristics?
                    if let charDict = result["characteristics"].dictionary {
                        characteristics = Plant.PlantCharacteristics(
                            toxicToPets: charDict["toxicToPets"].boolean ?? false,
                            airPurifying: charDict["airPurifying"].boolean ?? false,
                            flowering: charDict["flowering"].boolean ?? false,
                            difficulty: charDict["difficulty"].string ?? ""
                        )
                    }
                    
                    // Use a placeholder image for plants since we use pre-computed embeddings
                    let placeholderImage = UIImage(systemName: "leaf.fill") ?? UIImage()
                    let imageDigest = "precomputed_text_search"
                    
                    let record = Plant(name: name, scientificName: scientificName, price: price.doubleValue, location: location,
                                  wateringSchedule: wateringSchedule, careInstructions: careInstructions,
                                  characteristics: characteristics, image: placeholderImage, imageDigest: imageDigest)
                    
                    records.append(record)
                }
            }
            
            return records
        } catch {
            // If the query fails, return an empty result. This is expected when the user is
            // typing an FTS expression but they haven't completed typing so the query is
            // invalid. e.g. "(blue OR"
            return []
        }
    }
    
    private func searchPlants(vector: [Float]) -> [Record] {
        // Use pre-computed embeddings for plant search instead of database vector search
        print("🔍 Searching plants using pre-computed embeddings...")
        
        // Calculate similarities with all pre-computed embeddings
        var similarities: [(plantId: String, similarity: Float, distance: Float)] = []
        let embeddingLoader = BuildTimeEmbeddingLoader.shared
        
        for (plantId, plantEmbedding) in embeddingLoader.preComputedEmbeddings {
            let similarity = cosineSimilarity(vector, plantEmbedding.embedding)
            let distance = 1.0 - similarity // Convert similarity to distance
            similarities.append((plantId: plantId, similarity: similarity, distance: distance))
        }
        
        // Sort by similarity (descending) and filter good matches
        let sortedSimilarities = similarities.sorted { $0.similarity > $1.similarity }
        let bestMatches = sortedSimilarities.filter { $0.distance <= 0.25 }.prefix(10)
        
        if bestMatches.isEmpty {
            print("🤷‍♂️ No close plant matches found")
            return []
        }
        
        // Get plant data from database for the matched plant IDs
        var records = [Record]()
        var distances = [Double]()
        
        for match in bestMatches {
            if let plantRecord = getPlantRecord(plantId: match.plantId) {
                records.append(plantRecord)
                distances.append(Double(match.distance))
            }
        }
        
        // Post process and filter any matches that are too far away from the closest match
        var filteredRecords = [Record]()
        let minimumDistance: Double = {
            let minimumDistance = distances.min { a, b in a < b }
            return minimumDistance ?? .greatestFiniteMagnitude
        }()
        for (index, distance) in distances.enumerated() {
            if distance <= minimumDistance * 1.40 {
                let record = records[index]
                filteredRecords.append(record)
            }
        }
        
        print("✅ Found \(filteredRecords.count) plant matches using pre-computed embeddings")
        return filteredRecords
    }
    
    // Helper method to calculate cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    // Helper method to get plant record from database by plant ID
    private func getPlantRecord(plantId: String) -> Record? {
        let sql = """
            SELECT type, name, scientificName, price, location, wateringSchedule, careInstructions, characteristics
            FROM _
            WHERE type = "plant" AND _id = $plantId
        """
        
        do {
            let query = try collection.database.createQuery(sql)
            query.parameters = Parameters()
                .setString(plantId, forName: "plantId")
            
            for result in try query.execute() {
                if let name = result["name"].string,
                   let price = result["price"].number,
                   let location = result["location"].string,
                   let type = result["type"].string
                {
                    let scientificName = result["scientificName"].string
                    var wateringSchedule: Plant.WateringSchedule?
                    var careInstructions: Plant.CareInstructions?
                    var characteristics: Plant.PlantCharacteristics?
                    
                    if let scheduleDict = result["wateringSchedule"].dictionary {
                        wateringSchedule = Plant.WateringSchedule(
                            frequency: scheduleDict["frequency"].string ?? "",
                            amount: scheduleDict["amount"].string ?? "",
                            notes: scheduleDict["notes"].string ?? ""
                        )
                    }
                    
                    if let careDict = result["careInstructions"].dictionary {
                        careInstructions = Plant.CareInstructions(
                            light: careDict["light"].string ?? "",
                            temperature: careDict["temperature"].string ?? "",
                            humidity: careDict["humidity"].string ?? "",
                            fertilizer: careDict["fertilizer"].string ?? "",
                            pruning: careDict["pruning"].string ?? ""
                        )
                    }
                    
                    if let charDict = result["characteristics"].dictionary {
                        characteristics = Plant.PlantCharacteristics(
                            toxicToPets: charDict["toxicToPets"].boolean ?? false,
                            airPurifying: charDict["airPurifying"].boolean ?? false,
                            flowering: charDict["flowering"].boolean ?? false,
                            difficulty: charDict["difficulty"].string ?? ""
                        )
                    }
                    
                    // Create a placeholder image since we don't store images for plants anymore
                    let placeholderImage = UIImage(systemName: "leaf.fill") ?? UIImage()
                    let imageDigest = "precomputed_\(plantId)"
                    
                    let record = Plant(name: name, scientificName: scientificName, price: price.doubleValue, location: location,
                                  wateringSchedule: wateringSchedule, careInstructions: careInstructions,
                                  characteristics: characteristics, image: placeholderImage, imageDigest: imageDigest)
                    
                    return record
                }
            }
        } catch {
            print("Database.getPlantRecord(plantId:): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Async Indexing
    
    private let asyncIndexQueue = DispatchQueue(label: "AsyncIndexUpdateQueue")
    
    private func setupAsyncIndexing(for collection: CouchbaseLiteSwift.Collection) {
        // Immediately update the async indexes
        asyncIndexQueue.async { [weak self] in
            do {
                try self?.updateAsyncIndexes(for: collection)
            } catch {
                print("Error updating async indexes: \(error)")
            }
        }
        
        // When the collection changes, update the async indexes
        collection.addChangeListener { [weak self] _ in
            self?.asyncIndexQueue.async {
                do {
                    try self?.updateAsyncIndexes(for: collection)
                } catch {
                    print("Error updating async indexes: \(error)")
                }
            }
        }
    }
    
    private func updateAsyncIndexes(for collection: CouchbaseLiteSwift.Collection) throws {
        var imagesBatchCount = 0
        var facesBatchCount = 0
        
        // Check if image vector index exists (for non-plant items)
        if let imageVectorIndex = try collection.index(withName: "ImageVectorIndex") {
            // Update the images vector index with smaller batches for large datasets
            while (true) {
                guard let indexUpdater = try imageVectorIndex.beginUpdate(limit: 5) else {
                    break // Up to date
                }
                imagesBatchCount += 1
                
                print("Processing image vector batch \(imagesBatchCount) (\(indexUpdater.count) items)...")
                
                // Generate the new embedding and set it in the index
                for i in 0..<indexUpdater.count {
                    if let data = indexUpdater.blob(at: i)?.content, let image = UIImage(data: data) {
                        let embedding = AI.shared.embedding(for: image, attention: .none)
                        try indexUpdater.setVector(embedding, at: i)
                    } else {
                        print("Warning: Could not process image data for vector index at position \(i)")
                    }
                }
                try indexUpdater.finish()
                
                // Add a small delay between batches to prevent overwhelming the system
                Thread.sleep(forTimeInterval: 0.2)
            }
        } else {
            print("🌱 ImageVectorIndex not found - using pre-computed embeddings for plants")
        }
        
        // Check if face vector index exists (for non-plant items)
        if let faceVectorIndex = try collection.index(withName: "FaceVectorIndex") {
            // Update the faces vector index with smaller batches for large datasets
            while (true) {
                guard let indexUpdater = try faceVectorIndex.beginUpdate(limit: 5) else {
                    break // Up to date
                }
                facesBatchCount += 1
                
                print("Processing face vector batch \(facesBatchCount) (\(indexUpdater.count) items)...")
                
                // Generate the new embedding and set it in the index
                for i in 0..<indexUpdater.count {
                    if let data = indexUpdater.blob(at: i)?.content, let image = UIImage(data: data) {
                        let embedding = AI.shared.embedding(for: image, attention: .faces)
                        try indexUpdater.setVector(embedding, at: i)
                    } else {
                        print("Warning: Could not process face image data for vector index at position \(i)")
                    }
                }
                try indexUpdater.finish()
                
                // Add a small delay between batches to prevent overwhelming the system
                Thread.sleep(forTimeInterval: 0.2)
            }
        } else {
            print("🌱 FaceVectorIndex not found - using pre-computed embeddings for plants")
        }
        
        if imagesBatchCount > 0 || facesBatchCount > 0 {
            print("Vector indexing complete! Processed \(imagesBatchCount) image batches and \(facesBatchCount) face batches.")
        } else {
            print("🚀 No vector indexing needed - optimized with pre-computed embeddings!")
        }
     }
    

    
    // MARK: - Records
    

    
    class Plant: Record {
        let name: String?
        let scientificName: String?
        let price: Double?
        let location: String?
        let wateringSchedule: WateringSchedule?
        let careInstructions: CareInstructions?
        let characteristics: PlantCharacteristics?
        
        struct WateringSchedule {
            let frequency: String
            let amount: String
            let notes: String
        }
        
        struct CareInstructions {
            let light: String
            let temperature: String
            let humidity: String
            let fertilizer: String
            let pruning: String
        }
        
        struct PlantCharacteristics {
            let toxicToPets: Bool
            let airPurifying: Bool
            let flowering: Bool
            let difficulty: String
        }
        
        fileprivate init(name: String, scientificName: String?, price: Double, location: String, 
                        wateringSchedule: WateringSchedule?, careInstructions: CareInstructions?, 
                        characteristics: PlantCharacteristics?, image: UIImage, imageDigest: String) {
            self.name = name
            self.scientificName = scientificName
            self.price = price
            self.location = location
            self.wateringSchedule = wateringSchedule
            self.careInstructions = careInstructions
            self.characteristics = characteristics
            super.init(title: name, subtitle: scientificName ?? "", details: String(format: "$%.02f - %@", price, location), image: image, imageDigest: imageDigest)
        }
    }
    

    
    class Record: Equatable {
        let title: String?
        let subtitle: String?
        let details: String?
        let image: UIImage
        let imageDigest: String
        
        fileprivate init(image: UIImage, imageDigest: String) {
            self.title = nil
            self.subtitle = nil
            self.details = nil
            self.image = image
            self.imageDigest = imageDigest
        }
        
        fileprivate init(title: String, subtitle: String, details: String, image: UIImage, imageDigest: String) {
            self.title = title
            self.subtitle = subtitle
            self.details = details
            self.image = image
            self.imageDigest = imageDigest
        }
        
        static func == (lhs: Record, rhs: Record) -> Bool {
            return lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.details == rhs.details
            && lhs.imageDigest == rhs.imageDigest
        }
    }
    
    // MARK: - Sync
    
    private var replicator: Replicator?
    private var backgroundSyncTask: UIBackgroundTaskIdentifier?
    
    private var endpoint: Settings.Endpoint? {
        didSet {
            startSync()
        }
    }
    
    private func startSync() {
        stopSync()
        
        // Create and start the replicator
        replicator = createReplicator()
        replicator?.start()
    }
    
    private func stopSync() {
        if let replicator = replicator {
            // Stop and nullify the replicator
            replicator.stop()
            self.replicator = nil
        }
    }
    
    private func createReplicator() -> Replicator? {
        guard let endpoint = endpoint else { return nil }
        guard endpoint.url.scheme == "ws" || endpoint.url.scheme == "wss" else { return nil }
        
        // Set up the target endpoint.
        let target = URLEndpoint(url: endpoint.url)
        var config = ReplicatorConfiguration(target: target)
        config.addCollection(collection)
        config.replicatorType = .pull
        config.continuous = true
        
        // If the endpoint has a username and password then use then assign a basic
        // authenticator using the credentials.
        if let username = endpoint.username, let password = endpoint.password {
            config.authenticator = BasicAuthenticator(username: username, password: password)
        }

        // Create and return the replicator.
        let endpointReplicator = Replicator(config: config)
        return endpointReplicator
    }
    
    // MARK: - Demo
    
    private func loadDemoData(in collection: CouchbaseLiteSwift.Collection) {
        // Load demo data from JSON file in assets
        guard let url = Bundle.main.url(forResource: "demo-data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            print("Failed to load demo data from JSON file")
            return
        }
        
        let demoData = jsonArray
        print("Loading \(demoData.count) demo items...")
        
        // Process items in smaller batches to avoid memory pressure
        let batchSize = 10
        let totalBatches = (demoData.count + batchSize - 1) / batchSize
        
        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, demoData.count)
            let batch = Array(demoData[startIndex..<endIndex])
            
            print("Processing batch \(batchIndex + 1)/\(totalBatches) (\(batch.count) items)...")
            
            // Process each item in the batch
            for (_, var demoItemData) in batch.enumerated() {
                // Create a document
                let id = demoItemData.removeValue(forKey: "id") as? String
                let document = MutableDocument(id: id, data: demoItemData)
                
                // If the data has an image property with a string value, convert it to an image
                // from the app assets
                if let imageName = document["image"].string {
                    if let image = UIImage(named: "\(imageName)"),
                       let pngData = image.pngData()
                    {
                        document["image"].blob = Blob(contentType: "image/png", data: pngData)
                    } else {
                        print("Warning: Could not load image '\(imageName)'")
                    }
                }
                
                // If the data has an face property with a string value, convert it to an image
                // from the app assets
                if let imageName = document["face"].string {
                    if let image = UIImage(named: imageName),
                       let pngData = image.pngData()
                    {
                        document["face"].blob = Blob(contentType: "image/png", data: pngData)
                    } else {
                        print("Warning: Could not load face image '\(imageName)'")
                    }
                }
                
                do {
                    try collection.save(document: document)
                } catch {
                    print("Error saving document \(id ?? "unknown"): \(error.localizedDescription)")
                }
            }
            
            // Small delay between batches to prevent overwhelming the system
            if batchIndex < totalBatches - 1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        print("Demo data loading complete!")
    }
    

}
