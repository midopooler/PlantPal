//
//  Haptics.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit

class Haptics {
    static let shared = Haptics()
    
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        selectionFeedbackGenerator.prepare()
    }
    
    func generateSelectionFeedback() {
        selectionFeedbackGenerator.selectionChanged()
        selectionFeedbackGenerator.prepare()
    }
}
