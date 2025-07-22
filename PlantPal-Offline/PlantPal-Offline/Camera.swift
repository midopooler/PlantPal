//
//  Camera.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import AVFoundation
import Combine

class Camera : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    static let shared = Camera()
    
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "VideoSessionQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // Removed continuous capture - now using photo capture mode
    
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator!
    private var rotationObservers = [AnyObject]()
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var authorized: Bool = false
    @Published var records: [Database.Record] = []
    @Published var isProcessingPhoto: Bool = false // Add processing state
    let preview: Preview
    
    private override init() {
        self.preview = Preview(session: session)
        super.init()
        
        setup()
    }
    
    deinit {
        stop()
    }
    
    private func setup() {
        updateCameraAuthorization()
        
        Settings.shared.$frontCameraEnabled
            .sink { [weak self] frontCameraEnabled in
                self?.position = frontCameraEnabled ? .front : .back
            }.store(in: &cancellables)
    }
    
    private var position: AVCaptureDevice.Position = Settings.shared.frontCameraEnabled ? .front : .back {
        didSet {
            if position != oldValue {
                cameraPositionDidChange()
            }
        }
    }
    
    private func updateCameraAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: if !authorized { authorized = true }
        default: if authorized { authorized = false }
        }
    }
    
    var isRunning: Bool {
        return session.isRunning
    }
    
    func start(completion: ((_ started: Bool) -> Void)? = nil) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
                self.updateCameraAuthorization()
                if granted {
                    self.startSession()
                    completion?(true)
                } else {
                    completion?(false)
                }
            }
        } else {
            if status == .authorized {
                self.startSession()
                completion?(true)
            } else {
                completion?(false)
            }
            
        }
    }
    
    func stop() {
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
    
    private func startSession() {
        sessionQueue.async {
            guard self.session.isRunning == false else { return }
            
            self.setupSession()
            self.session.startRunning()
        }
    }
    
    private func setupSession() {
        guard session.inputs.count == 0 && session.outputs.count == 0 else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else {
            session.sessionPreset = .medium
        }
        
        do {
            if session.outputs.count == 0 {
                // Add photo output for single photo capture
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                } else {
                    throw "Could not add photo output"
                }
                
                // Keep video output for preview only (no continuous processing)
                if session.canAddOutput(videoOutput) {
                    videoOutput.alwaysDiscardsLateVideoFrames = true
                    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                    // Remove continuous delegate - no more continuous processing
                    // videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                    session.addOutput(videoOutput)
                } else {
                    throw "Could not add video output"
                }
            }
            
            if session.inputs.count == 0 {
                try updateVideoInputDevice()
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func updateVideoInputDevice() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Get the video device
        guard let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        else {
            throw "No video device found"
        }
        
        // Configure the device
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        } catch {
            print("Error configuring video device: \(error)")
        }
        
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: device)
            if let currentInput = session.inputs.first {
                if currentInput.isEqualTo(input) { return }
                session.removeInput(currentInput)
            }
        } catch {
            throw "Could not get video input"
        }
        
        if !session.canAddInput(input) {
            throw "Could not add video input"
        }
        
        session.addInput(input)
        
        createRotationCoordinator(for: device, previewLayer: preview.previewLayer)
    }
    
    private func createRotationCoordinator(for device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) {
        // Create a new rotation coordinator for this device
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        
        // Cancel previous observations
        rotationObservers.removeAll()
        
        // Add observers to monitor future changes
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new, .initial]) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                DispatchQueue.main.async {
                    self.preview.previewLayer.connection?.videoRotationAngle = angle
                }
            }
        )
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new, .initial]) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                self.videoOutput.connections.forEach { $0.videoRotationAngle = angle }
            }
        )
    }
    
    private func cameraPositionDidChange() {
        sessionQueue.async {
            if self.session.inputs.count == 0 { return }
            
            do {
                try self.updateVideoInputDevice()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        guard !isProcessingPhoto else { return } // Prevent multiple captures
        
        isProcessingPhoto = true
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { isProcessingPhoto = false }
        
        guard error == nil else {
            print("Photo capture error: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to convert photo to UIImage")
            return
        }
        
        // Get the bounds and focus rect for cropping on main thread
        DispatchQueue.main.async {
            let previewBounds = self.preview.bounds
            let focusRect = self.preview.focusRect
            
            // Process the captured photo on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                // Crop the image to the viewfinder area
                let croppedImage = self.cropImage(image, toFocusRect: focusRect, inPreviewBounds: previewBounds)
                
                // Search for plants in the cropped image
                let records = Database.shared.search(image: croppedImage)
                
                // Update results on main thread
                DispatchQueue.main.async {
                    self.records = records
                }
            }
        }
    }
    
    // Remove old continuous processing - no longer needed
    /*
    func shouldCaptureImage() -> Bool {
        // Removed - no longer using continuous capture
    }
  
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Removed - no longer using continuous processing
    }
    */
    
    private func cropImage(_ image: UIImage, toFocusRect focusRect: CGRect, inPreviewBounds previewBounds: CGRect) -> UIImage {
        let imageWidth = CGFloat(image.size.width)
        let imageHeight = CGFloat(image.size.height)

        // Calculate scale and offset based on videoGravity
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        switch preview.previewLayer.videoGravity {
        case .resizeAspectFill:
            scale = max(previewBounds.width / imageWidth, previewBounds.height / imageHeight)
            offsetX = (previewBounds.width - imageWidth * scale) / 2
            offsetY = (previewBounds.height - imageHeight * scale) / 2
        default: // .resizeAspect, .resize
            scale = min(previewBounds.width / imageWidth, previewBounds.height / imageHeight)
            offsetX = (previewBounds.width - imageWidth * scale) / 2
            offsetY = (previewBounds.height - imageHeight * scale) / 2
        }

        // Convert the focusRect from preview coordinates to image coordinates
        let focusRectInImage = CGRect(
            x: (focusRect.origin.x - offsetX) / scale,
            y: (focusRect.origin.y - offsetY) / scale,
            width: focusRect.width / scale,
            height: focusRect.height / scale
        )

        // Render the new image with the specified crop rectangle size
        let croppedImage = UIGraphicsImageRenderer(size: focusRectInImage.size).image { _ in
            // Calculate the point to start drawing the image to crop it correctly
            let drawPoint = CGPoint(x: -focusRectInImage.origin.x, y: -focusRectInImage.origin.y)
            image.draw(at: drawPoint)
        }

        return croppedImage
    }
    
    class Preview: UIView {
        private let viewfinderImageView = UIImageView()
        private var viewfinderWidthConstraint: NSLayoutConstraint?
        
        let previewLayer: AVCaptureVideoPreviewLayer
        var focusRect: CGRect { viewfinderImageView.frame }
        
        init(session: AVCaptureSession) {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
            super.init(frame: .zero)
            
            setup()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) not supported.")
        }
        
        private func setup() {
            self.backgroundColor = .systemBackground
            
            layer.addSublayer(previewLayer)
            
            viewfinderImageView.image = UIImage(systemName: "viewfinder", withConfiguration: UIImage.SymbolConfiguration(weight: .ultraLight))
            viewfinderImageView.tintColor = .white
            addSubview(viewfinderImageView)
        }
        
        private func layout() {
            // Layout preview layer
            previewLayer.frame = self.bounds
            
            // Layout viewfinder
            let viewfinderSize = 0.7 * min(self.bounds.width, self.bounds.height)
            let centeredX = (self.bounds.width - viewfinderSize) / 2
            let centeredY = (self.bounds.height - viewfinderSize) / 2
            viewfinderImageView.frame = CGRect(x: centeredX, y: centeredY, width: viewfinderSize, height: viewfinderSize)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layout()
        }
        
        func show(animations: (() -> Void)? = nil, completion: (() -> Void)? = nil, animated: Bool = true) {
            if animated == false {
                self.alpha = 1
                animations?()
                completion?()
                return
            }
            
            UIView.animate(withDuration: 0.2, delay: 0.5) {
                self.alpha = 1
                animations?()
            } completion: { _ in
                completion?()
            }
        }
        
        func hide(animations: (() -> Void)? = nil, completion: (() -> Void)? = nil, animated: Bool = true) {
            if animated == false {
                self.alpha = 0
                animations?()
                completion?()
                return
            }
            
            UIView.animate(withDuration: 0.2) {
                self.alpha = 0
                animations?()
            } completion: { _ in
                completion?()
            }
        }
    }
}

extension AVCaptureInput {
    func isEqualTo(_ other: AVCaptureInput) -> Bool {
        if let m = self as? AVCaptureDeviceInput, let o = other as? AVCaptureDeviceInput {
            return m.device.uniqueID == o.device.uniqueID
        }
        return false
    }
}

extension String: Error, LocalizedError {
    public var errorDescription: String? { return self }
}
