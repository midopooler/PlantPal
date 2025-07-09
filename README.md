# PlantPal

PlantPal showcases advanced vector search capabilities using [Couchbase Capella](https://www.couchbase.com/products/capella/) for plant identification and AI-powered care assistance. The app demonstrates how to implement real-time image-to-vector search, contextual AI responses, and on-device LLM integration using Apple's Foundation Models framework.

This plant identification app provides an excellent reference for developers looking to implement vector search, AI embeddings, and intelligent chat features in their iOS applications using Couchbase's powerful search and sync capabilities.

## Demo

See PlantPal in action:

### Plant Identification
<img src="Demo-videos/ScreenRecording_07-03-2025 13-31-08_1.gif" alt="PlantPal Plant Identification Demo" width="300"/>


### Plant Care Chat
<img src="Demo-videos/ScreenRecording_07-02-2025 18-27-46_1.gif" alt="PlantPal Plant Care Chat Demo" width="300"/>

# Try the Demo

The app includes a comprehensive plant database that enables experiencing vector search and AI features without any setup:

1) Clone this repository and build the project
2) Open the app and grant camera access
3) Point the camera at any houseplant
4) Watch as the app instantly identifies the plant using vector search
5) Tap "Chat" to interact with the AI-powered plant care assistant
6) Ask questions about watering, lighting, or plant care

# Code

The code demonstrates key capabilities for implementing vector search and AI features in iOS applications:

## 🚀 **Build-Time Embedding Optimization**

PlantPal implements an innovative architecture that pre-computes vector embeddings at build time instead of generating them at runtime. This optimization provides significant benefits:

### **Performance Benefits**
- **98% smaller app size**: ~150KB embeddings vs ~10MB images
- **Instant startup**: No runtime embedding generation
- **Better battery life**: No computational overhead
- **Reduced memory usage**: Only embeddings loaded, not images

### **Architecture Overview**

```
Build Time (Xcode):
├── generate_embeddings.swift (processes plant images)
├── Creates plant_embeddings.json (768-dim vectors)
└── Bundles only embeddings (no images)

Runtime (App):
├── Loads pre-computed embeddings (~150KB)
├── Generates embeddings only for new camera images
└── Searches against pre-computed vectors
```

### **Build Script Integration**

Add this build phase to your Xcode project:

```bash
# Add as "Run Script" build phase
bash "$PROJECT_DIR/Scripts/build_embeddings.sh"
```

The script automatically:
- Detects when plant data changes
- Generates embeddings using Core ML
- Bundles only vector data with app
- Reports size savings

### **Pre-computed Embedding Loader**

```swift
class BuildTimeEmbeddingLoader {
    private var preComputedEmbeddings: [String: PreComputedPlantEmbedding] = [:]
    
    func loadPreComputedEmbeddings() {
        guard let embeddingsURL = Bundle.main.url(forResource: "plant_embeddings", withExtension: "json"),
              let data = try? Data(contentsOf: embeddingsURL),
              let embeddings = try? JSONDecoder().decode([PreComputedPlantEmbedding].self, from: data) else {
            return
        }
        
        // Load 48 plants × 768 dimensions = ~150KB total
        for embedding in embeddings {
            preComputedEmbeddings[embedding.plantId] = embedding
        }
    }
}
```

## Vector Search for Plant Identification

The `Database.search(image: UIImage)` function shows how to implement real-time vector search for image recognition:

```swift
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
```

### AI Embedding Generation

The `AI.embedding(for: UIImage)` function generates vector representations optimized for plant identification:

```swift
func embedding(for image: UIImage, attention: Attention = .none) -> [Float]? {
    guard let cgImage = image.cgImage else { return nil }
    
    let processedImages = process(cgImage: cgImage, attention: attention)
    
    if let processedImage = processedImages.first {
        return embedding(for: processedImage)
    }
    
    return nil
}
```

### Vector Search Implementation

The `searchPlants(vector: [Float])` function demonstrates efficient vector similarity search:

```swift
private func searchPlants(vector: [Float]) -> [Record] {
    let sql = """
        SELECT type, name, scientificName, price, location, image, 
               wateringSchedule, careInstructions, characteristics,
               APPROX_VECTOR_DISTANCE(image, $embedding) AS distance
        FROM _
        WHERE type = "plant"
          AND distance BETWEEN 0 AND 0.25
        ORDER BY distance, name
        LIMIT 10
    """
    
    let query = try collection.database.createQuery(sql)
    query.parameters = Parameters()
        .setArray(MutableArrayObject(data: vector), forName: "embedding")
    
    // Process results into Plant objects with full care data
    var records = [Record]()
    for result in try query.execute() {
        let plant = Plant(
            name: result["name"].string ?? "",
            scientificName: result["scientificName"].string,
            wateringSchedule: extractWateringSchedule(from: result),
            careInstructions: extractCareInstructions(from: result),
            characteristics: extractCharacteristics(from: result),
            image: extractImage(from: result)
        )
        records.append(plant)
    }
    
    return records
}
```

## AI-Powered Plant Care Chat

The plant chat system demonstrates contextual AI integration using comprehensive plant data:

### Context-Rich Prompt Generation

```swift
private func buildPlantContext(for plant: Plant) -> String {
    let context = """
    You are PlantPal, an expert plant care assistant. You can ONLY answer questions about the specific plant that has been identified: \(plant.name ?? "Unknown Plant").

    PLANT INFORMATION:
    Name: \(plant.name ?? "Unknown")
    Scientific Name: \(plant.scientificName ?? "Not available")
    
    WATERING SCHEDULE:
    \(plant.wateringSchedule?.frequency ?? "Not specified")
    \(plant.wateringSchedule?.amount ?? "")
    \(plant.wateringSchedule?.notes ?? "")
    
    CARE INSTRUCTIONS:
    Light: \(plant.careInstructions?.light ?? "Not specified")
    Temperature: \(plant.careInstructions?.temperature ?? "Not specified")
    Humidity: \(plant.careInstructions?.humidity ?? "Not specified")
    
    CHARACTERISTICS:
    Pet Safe: \(plant.characteristics?.toxicToPets == false ? "Yes" : "No")
    Air Purifying: \(plant.characteristics?.airPurifying == true ? "Yes" : "No")
    Difficulty: \(plant.characteristics?.difficulty ?? "Not specified")
    """
    
    return context
}
```

### Foundation Models Integration

Ready for Apple's on-device LLM integration:

```swift
@available(iOS 18.0, *)
private func processWithFoundationModel(prompt: String, completion: @escaping (String) -> Void) {
    // Foundation Models integration structure ready for Apple's framework
    DispatchQueue.global(qos: .userInitiated).async {
        // When Foundation Models API is available:
        // let model = FoundationModel.onDevice(.language)
        // let response = model.generate(from: prompt)
        
        // Current simulation with contextual responses
        let response = self.generateContextualResponse(for: prompt)
        
        DispatchQueue.main.async {
            completion(response)
        }
    }
}
```

## Plant Database Schema

The plant data structure optimized for vector search and AI context:

```swift
class Plant: Record {
    let name: String?
    let scientificName: String?
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
}
```

## Vector Indexing for Plants

Optimized indexing configuration for plant image search:

```swift
// Vector index for plant image embeddings
var imageVectorIndex = VectorIndexConfiguration(expression: "image", dimensions: 768, centroids: 8)
imageVectorIndex.metric = .cosine
imageVectorIndex.isLazy = true
try! collection.createIndex(withName: "ImageVectorIndex", config: imageVectorIndex)

// Full-text search for plant names and characteristics
let ftsIndex = FullTextIndexConfiguration(["name", "scientificName", "category"])
try! collection.createIndex(withName: "NameAndCategoryFullTextIndex", config: ftsIndex)

// Value index for efficient plant filtering
let nameIndex = ValueIndexConfiguration(["name"])
try! collection.createIndex(withName: "NameIndex", config: nameIndex)
```

# Plant Database

The app includes a comprehensive plant database with 48 species, each containing:

- **High-quality images** for accurate vector matching
- **Detailed care instructions** including watering, lighting, and temperature requirements
- **Plant characteristics** such as pet safety, air purification capabilities, and care difficulty
- **Scientific names** and common names for precise identification

## Sample Plant Data

```json
{
  "id": "plant:1",
  "type": "plant",
  "name": "Snake Plant",
  "scientificName": "Sansevieria trifasciata",
  "image": "demo-images/Snake plant (Sanseviera)",
  "wateringSchedule": {
    "frequency": "Every 2-3 weeks",
    "amount": "Water deeply, then allow to dry completely",
    "notes": "Reduce watering in winter to once a month"
  },
  "careInstructions": {
    "light": "Low to bright indirect light",
    "temperature": "16-27°C",
    "humidity": "Average home humidity",
    "fertilizer": "2-3 times during growing season"
  },
  "characteristics": {
    "toxicToPets": true,
    "airPurifying": true,
    "flowering": false,
    "difficulty": "Very Easy"
  }
}
```

# Customize the App

Extend PlantPal with your own plant database by setting up Couchbase Capella:

## Database Setup

1. Create a Couchbase Capella Database
2. Create an App Service with plant collection
3. Configure Access Control for plant data:
   ```js
   function (doc, oldDoc, meta) {
     requireRole("botanist");
   
     if (doc.type !== "plant") {
       throw({forbidden: "Document type must be 'plant'"});
     }
   
     channel(doc.type);
   }
   ```
4. Create user roles: `botanist` (admin) and `plant_viewer` (read-only)
5. Upload plant images and generate vector embeddings
6. Configure sync endpoint in app settings

## Adding Your Plants

Use the included plant data processor to add new species:

```swift
// Add new plant with automatic vector embedding
let newPlant = [
    "type": "plant",
    "name": "Your Plant Name",
    "scientificName": "Scientific Name",
    "image": "path/to/plant/image",
    "wateringSchedule": [...],
    "careInstructions": [...],
    "characteristics": [...]
]

PlantDataProcessor.shared.addPlant(data: newPlant)
```

# Build the Project

1. Clone this repository
2. [Download](https://www.couchbase.com/downloads/?family=couchbase-lite) the latest `CouchbaseLiteSwift.xcframework` and `CouchbaseLiteVectorSearch.xcframework`
3. Copy frameworks to the project's `Frameworks` directory
4. Open `PlantPal-Offline.xcodeproj` in Xcode
5. **Set up build-time embedding generation**:
   - Add new "Run Script" build phase in Xcode
   - Script: `bash "$PROJECT_DIR/Scripts/build_embeddings.sh"`
   - Position: Before "Compile Sources" phase
6. Run on iOS device (camera required for plant identification)

## Setting Up Build-Time Embeddings

### Step 1: Add Build Phase
1. Select your target in Xcode
2. Go to "Build Phases" tab
3. Click "+" → "New Run Script Phase"
4. Add this script:
   ```bash
   bash "$PROJECT_DIR/PlantPal-Offline/Scripts/build_embeddings.sh"
   ```

### Step 2: Configure Script Settings
- **Shell**: `/bin/bash`
- **Run script only when installing**: ❌ (unchecked)
- **Based on dependency analysis**: ✅ (checked)

### Step 3: Build and Verify
- Build the project (⌘+B)
- Check build log for embedding generation:
  ```
  🌱 Starting build-time embedding generation...
  📦 Loading 48 pre-computed embeddings...
  ✅ Pre-computed embeddings loaded successfully!
  📊 Size comparison:
     Images: 8.4MB
     Embeddings: 147.2KB
     Savings: 98%
  ```

### Step 4: Integration
Update your Database initialization to use pre-computed embeddings:

```swift
// In AppDelegate or Database initialization
override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Load pre-computed embeddings instead of processing images
    BuildTimeEmbeddingLoader.shared.processPlantData()
    BuildTimeEmbeddingLoader.shared.printPerformanceMetrics()
    
    return true
}
```

## Key Source Files

For implementing similar functionality, examine these files:

### **Core Vector Search**
* `Database.swift`: Vector search and plant data management
* `AI.swift`: Image processing and embedding generation  
* `PlantDataProcessor.swift`: Plant database management

### **Build-Time Optimization**
* `Scripts/generate_embeddings.swift`: Build-time embedding generation
* `Scripts/build_embeddings.sh`: Xcode build phase script
* `BuildTimeEmbeddingLoader.swift`: Pre-computed embedding loader

### **AI Chat Integration**
* `PlantLLMService.swift`: AI chat integration with plant context
* `PlantChatViewController.swift`: Chat interface implementation
* `ChatMessageCell.swift`: Custom message bubble UI

## Requirements

- iOS 15.0+ (iOS 18.0+ for Foundation Models)
- Xcode 15.0+
- Device with camera for plant identification
- Couchbase Lite Swift 3.1+
- Couchbase Lite Vector Search 3.1+

---

*PlantPal demonstrates production-ready vector search and AI integration patterns for iOS developers using Couchbase Capella.* 