//
//  LoginViewController.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Combine

class LoginViewController: UIViewController {
    @IBOutlet weak var tryNowButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialState()
        
        // Listen for plant processing progress
        PlantDataProcessor.shared.$processingProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateProgress(progress)
            }
            .store(in: &cancellables)
        
        PlantDataProcessor.shared.$isProcessingComplete
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isComplete in
                if isComplete {
                    self?.enableTryNowButton()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialState() {
        // Disable try now button until processing is complete
        tryNowButton?.isEnabled = false
        tryNowButton?.alpha = 0.5
        
        // Show initial progress state
        if PlantDataProcessor.shared.isProcessingComplete {
            enableTryNowButton()
        } else {
            updateProgress(PlantDataProcessor.shared.processingProgress)
        }
    }
    
    private func updateProgress(_ progress: PlantDataProcessor.ProcessingProgress) {
        progressView?.progress = progress.percentage
        progressLabel?.text = progress.message
        progressView?.isHidden = false
        progressLabel?.isHidden = false
    }
    
    private func enableTryNowButton() {
        tryNowButton?.isEnabled = true
        tryNowButton?.alpha = 1.0
        progressView?.isHidden = true
        progressLabel?.isHidden = true
    }
    
    @IBAction func tryNow(_ sender: Any) {
        // When the user chooses to try now, enable the demo
        Settings.shared.isDemoEnabled = true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
