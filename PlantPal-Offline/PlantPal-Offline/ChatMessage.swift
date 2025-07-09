//
//  ChatMessage.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import Foundation

struct ChatMessage {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp = Date()
} 