//
//  TabBarController.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Combine

class TabBarController: UITabBarController {
    
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    private func setup() {
        tabBar.tintColor = .label
        tabBar.unselectedItemTintColor = .secondaryLabel
    }
    
    // MARK: - Full Screen
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
