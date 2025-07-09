//
//  PlantLLMService.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import Foundation
import UIKit

// MARK: - Foundation Models Framework Integration
// Note: This will use Apple's new Foundation Models framework when available
// For now, we'll create a compatible interface structure

@available(iOS 18.0, *)
class PlantLLMService {
    
    // MARK: - Properties
    private var isModelLoaded = false
    private let modelConfiguration = FoundationModelConfiguration()
    
    // MARK: - Foundation Model Configuration
    private struct FoundationModelConfiguration {
        let maxTokens: Int = 2048
        let temperature: Float = 0.7
        let topP: Float = 0.9
    }
    
    // MARK: - Initialization
    init() {
        setupFoundationModel()
    }
    
    // MARK: - Model Setup
    private func setupFoundationModel() {
        // This will use Apple's Foundation Models framework
        // For development, we'll simulate the setup
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Simulate model loading time
            Thread.sleep(forTimeInterval: 1.0)
            
            DispatchQueue.main.async {
                self?.isModelLoaded = true
                print("🌿 PlantLLM: On-device model loaded successfully")
            }
        }
    }
    
    // MARK: - Chat Interface
    func sendMessage(_ message: String, for plant: Database.Plant, completion: @escaping (String) -> Void) {
        guard isModelLoaded else {
            completion("I'm still loading my plant knowledge. Please try again in a moment! 🌱")
            return
        }
        
        let context = createPlantContext(for: plant)
        let prompt = buildPrompt(context: context, userMessage: message)
        
        // Process with Foundation Models
        processWithFoundationModel(prompt: prompt, completion: completion)
    }
    
    // MARK: - Context Creation
    private func createPlantContext(for plant: Database.Plant) -> String {
        let plantName = plant.name ?? "Unknown Plant"
        var context = """
        You are PlantPal, a specialized plant care assistant. You can ONLY answer questions about the specific plant that was just identified through image scanning.
        
        IDENTIFIED PLANT INFORMATION:
        • Name: \(plantName)
        """
        
        if let scientificName = plant.scientificName {
            context += "\n• Scientific Name: \(scientificName)"
        }
        
        // Add watering schedule
        if let watering = plant.wateringSchedule {
            context += """
            
            WATERING CARE FOR THIS PLANT:
            • Frequency: \(watering.frequency)
            • Amount: \(watering.amount)
            • Notes: \(watering.notes)
            """
        }
        
        // Add care instructions
        if let care = plant.careInstructions {
            context += """
            
            CARE INSTRUCTIONS FOR THIS PLANT:
            • Light Requirements: \(care.light)
            • Temperature: \(care.temperature)
            • Humidity: \(care.humidity)
            • Fertilizer: \(care.fertilizer)
            • Pruning: \(care.pruning)
            """
        }
        
        // Add characteristics
        if let characteristics = plant.characteristics {
            context += """
            
            THIS PLANT'S CHARACTERISTICS:
            • Difficulty Level: \(characteristics.difficulty)
            • Air Purifying: \(characteristics.airPurifying ? "Yes" : "No")
            • Pet Safe: \(characteristics.toxicToPets ? "No - Toxic to pets" : "Yes - Safe for pets")
            • Flowering: \(characteristics.flowering ? "Yes" : "No")
            """
        }
        
        context += """
        
        STRICT INSTRUCTIONS:
        • You can ONLY answer questions about this specific plant: \(plantName)
        • Use ONLY the information provided above about this identified plant
        • If asked about other plants, respond: "I can only help with your \(plantName). Please ask me about this specific plant."
        • If asked general gardening questions not about this plant, respond: "I'm focused on helping with your \(plantName). What would you like to know about this specific plant?"
        • If asked non-plant questions, respond: "I can only help with plant care for your \(plantName). What can I tell you about this plant?"
        • Keep responses friendly but focused strictly on this identified plant
        • Use plant emojis occasionally 🌿
        • If you don't have specific information about something for this plant, say "I don't have that specific information about your \(plantName)"
        
        """
        
        return context
    }
    
    private func buildPrompt(context: String, userMessage: String) -> String {
        return """
        \(context)
        
        Human: \(userMessage)
        
        PlantPal:
        """
    }
    
    // MARK: - Foundation Models Processing
    private func processWithFoundationModel(prompt: String, completion: @escaping (String) -> Void) {
        // This is where we'll integrate with Apple's Foundation Models framework
        // Using the new Foundation Models API announced in 2025
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Simulate processing time for now
            Thread.sleep(forTimeInterval: Double.random(in: 0.5...2.0))
            
            let response = self?.generatePlantResponse(for: prompt) ?? "I'm having trouble thinking right now. Could you try asking again? 🌿"
            
            DispatchQueue.main.async {
                completion(response)
            }
        }
    }
    
    // MARK: - Response Generation (Temporary Implementation)
    // Note: This will be replaced with actual Foundation Models API calls
    private func generatePlantResponse(for prompt: String) -> String {
        let userMessage = extractUserMessage(from: prompt)
        let plantName = extractPlantName(from: prompt)
        
        // First check if question is about this specific plant
        if !isQuestionAboutThisPlant(userMessage, plantName: plantName) {
            return generateRestrictionResponse(plantName: plantName, userMessage: userMessage)
        }
        
        // Analyze the user's question about this specific plant
        if containsWateringQuestion(userMessage) {
            return generateWateringResponse(from: prompt)
        } else if containsLightQuestion(userMessage) {
            return generateLightResponse(from: prompt)
        } else if containsPetSafetyQuestion(userMessage) {
            return generatePetSafetyResponse(from: prompt)
        } else if containsHealthQuestion(userMessage) {
            return generateHealthResponse(from: prompt)
        } else if containsCareTipsQuestion(userMessage) {
            return generateCareTipsResponse(from: prompt)
        } else {
            return generateOnPlantResponse(from: prompt)
        }
    }
    
    private func extractUserMessage(from prompt: String) -> String {
        let components = prompt.components(separatedBy: "Human: ")
        guard components.count > 1 else { return "" }
        
        return components[1].components(separatedBy: "\n\nPlantPal:").first ?? ""
    }
    
    private func extractPlantName(from prompt: String) -> String {
        // Extract plant name from the context
        let lines = prompt.components(separatedBy: "\n")
        for line in lines {
            if line.contains("• Name: ") {
                let plantName = line.replacingOccurrences(of: "• Name: ", with: "").trimmingCharacters(in: .whitespaces)
                // Remove any Optional() wrapper if present
                if plantName.hasPrefix("Optional(\"") && plantName.hasSuffix("\")") {
                    let start = plantName.index(plantName.startIndex, offsetBy: 10) // "Optional(\"".count
                    let end = plantName.index(plantName.endIndex, offsetBy: -2) // remove "\")"
                    return String(plantName[start..<end])
                }
                return plantName
            }
        }
        return "your plant"
    }
    
    private func isQuestionAboutThisPlant(_ message: String, plantName: String) -> Bool {
        let lowercaseMessage = message.lowercased()
        let lowercasePlantName = plantName.lowercased()
        
        // Check for off-topic indicators
        let offTopicKeywords = [
            // Other plants
            "rose", "sunflower", "tulip", "lily", "orchid", "cactus", "succulent", "fern", "palm", "ivy",
            "tomato", "cucumber", "lettuce", "basil", "mint", "rosemary", "lavender", "daisy", "pansy",
            // General gardening
            "garden", "soil mix", "fertilizer brand", "pest control", "greenhouse", "mulch", "compost",
            // Non-plant topics
            "weather", "recipe", "movie", "music", "sport", "politics", "technology", "car", "travel",
            "cooking", "what is", "tell me about", "how to make", "where can i", "when did"
        ]
        
        // If message doesn't contain the plant name and contains off-topic keywords
        if !lowercaseMessage.contains(lowercasePlantName) && 
           offTopicKeywords.contains(where: { lowercaseMessage.contains($0) }) {
            return false
        }
        
        // Check for direct questions about other plants
        if lowercaseMessage.contains("other plant") || 
           lowercaseMessage.contains("different plant") ||
           lowercaseMessage.contains("what plant") ||
           (lowercaseMessage.contains("plant") && !lowercaseMessage.contains(lowercasePlantName)) {
            return false
        }
        
        return true
    }
    
    private func generateRestrictionResponse(plantName: String, userMessage: String) -> String {
        let lowercaseMessage = userMessage.lowercased()
        
        if lowercaseMessage.contains("plant") && !lowercaseMessage.contains(plantName.lowercased()) {
            return "I can only help with your \(plantName). Please ask me about this specific plant! 🌿"
        } else if lowercaseMessage.contains("garden") || lowercaseMessage.contains("soil") || lowercaseMessage.contains("fertilizer") {
            return "I'm focused on helping with your \(plantName). What would you like to know about this specific plant? 🌱"
        } else {
            return "I can only help with plant care for your \(plantName). What can I tell you about this plant? 🌿"
        }
    }
    
    // MARK: - Question Analysis
    private func containsWateringQuestion(_ message: String) -> Bool {
        let waterKeywords = ["water", "watering", "irrigation", "drink", "thirsty", "dry", "moist", "soil"]
        return waterKeywords.contains { message.lowercased().contains($0) }
    }
    
    private func containsLightQuestion(_ message: String) -> Bool {
        let lightKeywords = ["light", "lighting", "sun", "sunny", "shade", "bright", "dark", "window"]
        return lightKeywords.contains { message.lowercased().contains($0) }
    }
    
    private func containsPetSafetyQuestion(_ message: String) -> Bool {
        let petKeywords = ["pet", "dog", "cat", "safe", "toxic", "poison", "eat", "chew"]
        return petKeywords.contains { message.lowercased().contains($0) }
    }
    
    private func containsHealthQuestion(_ message: String) -> Bool {
        let healthKeywords = ["healthy", "sick", "dying", "yellow", "brown", "wilting", "drooping", "problem"]
        return healthKeywords.contains { message.lowercased().contains($0) }
    }
    
    private func containsCareTipsQuestion(_ message: String) -> Bool {
        let careKeywords = ["care", "tips", "help", "advice", "how to", "maintain", "keep"]
        return careKeywords.contains { message.lowercased().contains($0) }
    }
    
    // MARK: - Response Generators
    private func generateWateringResponse(from prompt: String) -> String {
        let plantName = extractPlantName(from: prompt)
        
        // Extract specific watering information from context
        let wateringInfo = extractWateringInfo(from: prompt)
        
        if !wateringInfo.isEmpty {
            let baseResponse = "Here's the watering schedule for your \(plantName): 💧\n\n"
            return baseResponse + wateringInfo + "\n\n💡 Pro tip: Always check the soil moisture by inserting your finger 1-2 inches deep. Water when the top inch feels dry!"
        }
        
        // Fallback if no specific watering info found
        let responses = [
            "For your \(plantName), I recommend checking the soil moisture regularly! 💧 Stick your finger about 1-2 inches into the soil - if it feels dry, it's time to water. Most succulents like Aloe prefer less frequent but thorough watering.",
            "Great question about your \(plantName)! 🌊 Generally, Aloe plants prefer to dry out between waterings. Check the soil moisture and water when the top 1-2 inches feel dry, typically every 2-3 weeks depending on your home conditions."
        ]
        
        return responses.randomElement() ?? responses[0]
    }
    
    private func extractWateringInfo(from prompt: String) -> String {
        let lines = prompt.components(separatedBy: "\n")
        var wateringInfo = ""
        var inWateringSection = false
        
        for line in lines {
            if line.contains("WATERING CARE FOR THIS PLANT:") {
                inWateringSection = true
                continue
            } else if inWateringSection && line.contains("CARE INSTRUCTIONS") {
                break
            } else if inWateringSection && !line.isEmpty && line.contains("•") {
                let cleanLine = line.trimmingCharacters(in: .whitespaces)
                if cleanLine.contains("Frequency:") {
                    wateringInfo += "🗓️ **Frequency:** " + cleanLine.replacingOccurrences(of: "• Frequency: ", with: "") + "\n"
                } else if cleanLine.contains("Amount:") {
                    wateringInfo += "💦 **Amount:** " + cleanLine.replacingOccurrences(of: "• Amount: ", with: "") + "\n"
                } else if cleanLine.contains("Notes:") {
                    wateringInfo += "📝 **Notes:** " + cleanLine.replacingOccurrences(of: "• Notes: ", with: "") + "\n"
                }
            }
        }
        
        return wateringInfo.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateLightResponse(from prompt: String) -> String {
        let plantName = extractPlantName(from: prompt)
        
        // Extract specific lighting information from context
        let lightingInfo = extractLightingInfo(from: prompt)
        
        if !lightingInfo.isEmpty {
            let baseResponse = "Here are the lighting requirements for your \(plantName): ☀️\n\n"
            return baseResponse + lightingInfo + "\n\n💡 Pro tip: Watch your plant's leaves - they'll tell you if they're getting too much or too little light!"
        }
        
        // Fallback with specific advice for Aloe
        let responses = [
            "Your \(plantName) loves bright, indirect light! ☀️ Place it near a south or west-facing window, but avoid direct harsh sunlight which can burn the leaves. 4-6 hours of bright light per day is ideal.",
            "Great question about lighting your \(plantName)! 🌞 Aloe plants thrive in bright, indirect sunlight. A spot that gets morning sun and afternoon shade works perfectly. Avoid deep shade or harsh direct sun."
        ]
        
        return responses.randomElement() ?? responses[0]
    }
    
    private func extractLightingInfo(from prompt: String) -> String {
        let lines = prompt.components(separatedBy: "\n")
        var lightingInfo = ""
        var inCareSection = false
        
        for line in lines {
            if line.contains("CARE INSTRUCTIONS FOR THIS PLANT:") {
                inCareSection = true
                continue
            } else if inCareSection && line.contains("THIS PLANT'S CHARACTERISTICS:") {
                break
            } else if inCareSection && !line.isEmpty && line.contains("•") {
                let cleanLine = line.trimmingCharacters(in: .whitespaces)
                if cleanLine.contains("Light Requirements:") {
                    lightingInfo += "☀️ **Light:** " + cleanLine.replacingOccurrences(of: "• Light Requirements: ", with: "") + "\n"
                } else if cleanLine.contains("Temperature:") {
                    lightingInfo += "🌡️ **Temperature:** " + cleanLine.replacingOccurrences(of: "• Temperature: ", with: "") + "\n"
                } else if cleanLine.contains("Humidity:") {
                    lightingInfo += "💨 **Humidity:** " + cleanLine.replacingOccurrences(of: "• Humidity: ", with: "") + "\n"
                }
            }
        }
        
        return lightingInfo.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generatePetSafetyResponse(from prompt: String) -> String {
        let plantName = extractPlantName(from: prompt)
        
        // Extract specific pet safety information
        let petSafetyInfo = extractPetSafetyInfo(from: prompt)
        
        if petSafetyInfo.contains("toxic") || petSafetyInfo.contains("No - Toxic") {
            return "⚠️ **Important Safety Warning:** Your \(plantName) is toxic to pets! 🐕🐱\n\n" +
                   "Please keep it out of reach of dogs, cats, and other pets for their safety. Consider:\n" +
                   "• Hanging planters or high shelves\n" +
                   "• Pet-free rooms\n" +
                   "• Protective barriers\n\n" +
                   "If your pet ingests any part of this plant, contact your veterinarian immediately! 🚨"
        } else if petSafetyInfo.contains("safe") || petSafetyInfo.contains("Yes - Safe") {
            return "Great news! 🎉 Your \(plantName) is safe for pets according to the plant information.\n\n" +
                   "However, it's still good practice to:\n" +
                   "• Discourage pets from chewing on plants\n" +
                   "• Monitor for any unusual reactions\n" +
                   "• Keep plants clean and healthy\n\n" +
                   "Even safe plants can cause mild stomach upset if consumed in large quantities. 🐾"
        }
        
        // Fallback - specific advice for Aloe
        return "⚠️ **Pet Safety Alert:** Aloe plants can be mildly toxic to pets if ingested in large quantities! 🐕🐱\n\n" +
               "While not severely dangerous, Aloe can cause:\n" +
               "• Stomach upset\n" +
               "• Diarrhea\n" +
               "• Vomiting\n\n" +
               "Keep your \(plantName) out of reach as a precaution. If ingestion occurs, monitor your pet and contact your vet if symptoms persist. 🚨"
    }
    
    private func extractPetSafetyInfo(from prompt: String) -> String {
        let lines = prompt.components(separatedBy: "\n")
        var inCharacteristics = false
        
        for line in lines {
            if line.contains("THIS PLANT'S CHARACTERISTICS:") {
                inCharacteristics = true
                continue
            } else if inCharacteristics && line.contains("Pet Safe:") {
                return line.trimmingCharacters(in: .whitespaces)
            } else if inCharacteristics && !line.contains("•") && !line.isEmpty {
                break
            }
        }
        
        return ""
    }
    
    private func generateHealthResponse(from prompt: String) -> String {
        let plantName = extractPlantName(from: prompt)
        let responses = [
            "I'd love to help diagnose what's going on with your \(plantName)! 🔍 Can you tell me more about what you're seeing? Are the leaves changing color, dropping, or showing other signs?",
            "Let's figure this out together for your \(plantName)! 🌿 Plant problems usually relate to the care requirements shown above. What specific symptoms are you noticing?",
            "Don't worry, we can get your \(plantName) back to health! 💚 Could you describe what's concerning you? Compare what you're seeing to the care instructions above."
        ]
        
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateCareTipsResponse(from prompt: String) -> String {
        let plantName = extractPlantName(from: prompt)
        
        // Extract and provide comprehensive care overview
        let careOverview = extractCareOverview(from: prompt)
        
        if !careOverview.isEmpty {
            return "Here's a comprehensive care guide for your \(plantName): 🌟\n\n" + careOverview + 
                   "\n\n💚 **Key Success Tips:**\n" +
                   "• Observe your plant regularly for changes\n" +
                   "• Adjust care based on seasonal changes\n" +
                   "• Don't panic if something seems off - plants are resilient!\n" +
                   "• When in doubt, less is often more (especially with watering)\n\n" +
                   "What specific aspect would you like to discuss further? 😊"
        }
        
        // Fallback with general Aloe care tips
        return "Here are essential care tips for your \(plantName): 🌟\n\n" +
               "🌞 **Light:** Bright, indirect sunlight (4-6 hours daily)\n" +
               "💧 **Water:** Every 2-3 weeks, when soil is dry 1-2 inches deep\n" +
               "🌡️ **Temperature:** 65-75°F (18-24°C) is ideal\n" +
               "🪴 **Soil:** Well-draining cactus/succulent mix\n" +
               "🐕 **Pets:** Keep out of reach - mildly toxic if ingested\n\n" +
               "Your \(plantName) is relatively low-maintenance once you get the basics right! What would you like to know more about? 😊"
    }
    
    private func extractCareOverview(from prompt: String) -> String {
        let lines = prompt.components(separatedBy: "\n")
        var overview = ""
        var currentSection = ""
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespaces)
            
            if cleanLine.contains("WATERING CARE FOR THIS PLANT:") {
                currentSection = "watering"
                overview += "💧 **WATERING:**\n"
            } else if cleanLine.contains("CARE INSTRUCTIONS FOR THIS PLANT:") {
                currentSection = "care"
                overview += "\n🌱 **CARE REQUIREMENTS:**\n"
            } else if cleanLine.contains("THIS PLANT'S CHARACTERISTICS:") {
                currentSection = "characteristics"
                overview += "\n📋 **PLANT INFO:**\n"
            } else if cleanLine.contains("•") && !currentSection.isEmpty {
                let info = cleanLine.replacingOccurrences(of: "•", with: "  •")
                overview += info + "\n"
            }
        }
        
        return overview.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateOnPlantResponse(from prompt: String) -> String {
        let plantName = extractPlantName(from: prompt)
        let responses = [
            "I'm here to help with your \(plantName)! What specific questions do you have about caring for this plant? 🌿",
            "Feel free to ask me anything about your \(plantName)'s care, watering, lighting, or any concerns you might have! 🌱",
            "What would you like to know about your \(plantName)? I can help with watering, lighting, feeding, or general care tips for this specific plant! 🪴",
            "I'm focused on helping with your \(plantName)! What questions do you have about this plant? 🌿"
        ]
        
        return responses.randomElement() ?? responses[0]
    }
}

// MARK: - Fallback for iOS < 18.0
class PlantLLMServiceFallback {
    func sendMessage(_ message: String, for plant: Database.Plant, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 1.0)
            
            DispatchQueue.main.async {
                completion("I'd love to help with your \(plant.name)! 🌿 This feature requires iOS 18.0 or later with Apple's new Foundation Models framework. For now, you can refer to the detailed care information shown above your plant!")
            }
        }
    }
}

// MARK: - Availability Check
@available(iOS 18.0, *)
extension PlantLLMService {
    static var isAvailable: Bool {
        if #available(iOS 18.0, *) {
            return true
        } else {
            return false
        }
    }
} 
