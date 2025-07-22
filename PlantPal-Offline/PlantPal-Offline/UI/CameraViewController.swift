//
//  CamerViewController.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import AVFoundation
import Combine

class CameraViewController: RecordsViewController {
    @IBOutlet weak var explainerView: UIView!
    
    // Add shutter button
    private lazy var shutterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add inner circle for classic camera button look
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30
        innerCircle.isUserInteractionEnabled = false
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(innerCircle)
        
        NSLayoutConstraint.activate([
            innerCircle.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return button
    }()
    
    // Add processing indicator
    private lazy var processingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setup() {
        // Check the camera authorization and display the explainer if needed
        updateCameraAuthorization()
        
        let camera = Camera.shared
        camera.preview.frame = view.bounds
        camera.preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        camera.preview.previewLayer.videoGravity = .resizeAspectFill
        view.insertSubview(camera.preview, at: 0)
        
        // Add shutter button to the view
        setupShutterButton()
        
        // When the records from the camera change, update the records
        Camera.shared.$records
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] records in
                self?.records = records
                if records.count > 0 {
                    Haptics.shared.generateSelectionFeedback()
                }
            }.store(in: &cancellables)
        
        Camera.shared.$authorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authorized in
                self?.updateCameraAuthorization(authorized)
            }.store(in: &cancellables)
        
        // Listen for processing state changes
        Camera.shared.$isProcessingPhoto
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                self?.updateProcessingState(isProcessing)
            }.store(in: &cancellables)
    }
    
    private func setupShutterButton() {
        view.addSubview(shutterButton)
        view.addSubview(processingIndicator)
        
        NSLayoutConstraint.activate([
            // Shutter button at bottom center
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Processing indicator in center of shutter button
            processingIndicator.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            processingIndicator.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor)
        ])
    }
    
    @objc private func shutterButtonTapped() {
        guard Camera.shared.authorized && !Camera.shared.isProcessingPhoto else { return }
        
        // Provide haptic feedback
        Haptics.shared.generateSelectionFeedback()
        
        // Capture photo
        Camera.shared.capturePhoto()
    }
    
    private func updateProcessingState(_ isProcessing: Bool) {
        shutterButton.isEnabled = !isProcessing
        shutterButton.alpha = isProcessing ? 0.6 : 1.0
        
        if isProcessing {
            processingIndicator.startAnimating()
        } else {
            processingIndicator.stopAnimating()
        }
    }
    
    private func style() {
        tabBarController?.overrideUserInterfaceStyle = .dark
        updateStyleForRecords()
    }
    
    private func updateStyleForRecords() {
        let camera = Camera.shared
        let isShowingRecords = records.count > 0
        
        if isShowingRecords {
            // Hide the plant instruction label when showing records
            plantInstructionLabel?.isHidden = true
            // Hide shutter button when showing results
            shutterButton.isHidden = true
            
            // Stop the camera
            if camera.isRunning {
                camera.stop()
                // Hide the preview
                camera.preview.hide(animations: {
                    // Style the view for the records to be showing
                    self.view.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
                    self.updateStyleForCamera(isRunning: false)
                })
            }
        } else {
            // Show the plant instruction label when camera is active
            plantInstructionLabel?.isHidden = false
            // Show shutter button when in camera mode (if authorized)
            shutterButton.isHidden = !camera.authorized
            
            // Start the camera
            if !camera.isRunning {
                // Hide the preview
                camera.preview.hide(animations: {
                    // Style the view for the camera to be showing
                    self.view.backgroundColor = .black
                    self.updateStyleForCamera(isRunning: true)
                }, completion: {
                    // Then, start the camera
                    camera.start { started in
                        // Finally, if the camera was started successfully, show the preview
                        if started {
                            DispatchQueue.main.async {
                                camera.preview.show()
                            }
                        }
                    }
                })
            }
        }
    }
    
    func updateStyleForCamera(isRunning: Bool) {
        if isRunning {
            tabBarController?.tabBar.backgroundColor = .black.withAlphaComponent(0.7)
        } else {
            tabBarController?.tabBar.backgroundColor = nil
        }
    }
    
    private func updateCameraAuthorization(_ authorized: Bool? = nil) {
        let camera = Camera.shared
        let authorized = authorized ?? camera.authorized
        
        // If the camera is not enabled, show the explainer and hide the camera
        if authorized {
            // Show camera and hide explainer
            self.explainerView.alpha = 0
            camera.preview.show(animated: false)
            // Show plant instruction label when camera is authorized and no records are showing
            plantInstructionLabel?.isHidden = (records.count > 0)
            // Show shutter button when camera is authorized
            shutterButton.isHidden = false
        } else {
            // Show explainer and hide camera
            self.explainerView.alpha = 1
            camera.preview.hide(animated: false)
            // Hide plant instruction label when camera access is not granted
            plantInstructionLabel?.isHidden = true
            // Hide shutter button when camera access is not granted
            shutterButton.isHidden = true
        }
    }
    
    // MARK: - Records
    
    override var records: [Database.Record] {
        didSet {
            // When the records change, update the styling
            guard oldValue != records else { return }
            updateStyleForRecords()
        }
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        style()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop the camera
        Camera.shared.stop()
        Camera.shared.preview.hide(animated: false)
        updateStyleForCamera(isRunning: false)
    }
}
