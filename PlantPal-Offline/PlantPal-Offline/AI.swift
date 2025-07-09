//
//  AI.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Vision

struct AI {
    static let shared = AI()
    private init() {}
    
    enum Attention {
        case none, saliency(_ saliency: Saliency), foreground, faces, zoom(factors: [CGFloat])
        
        enum Saliency {
            case attention, objectness
        }
    }
    
    // MARK: - Embedding
    
    func embeddings(for image: UIImage, attention: Attention = .none) -> [[Float]] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Process the input image and generate the embeddings
        var embeddings = [[Float]]()
        let processedImages = process(cgImage: cgImage, attention: attention)
        for processedImage in processedImages {
            if let embedding = embedding(for: processedImage) {
                embeddings.append(embedding)
            }
        }
        
        return embeddings
    }
    
    func embedding(for image: UIImage, attention: Attention = .none) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Process the input image and generate the embedding
        var embedding: [Float]?
        if let processedImage = process(cgImage: cgImage, attention: attention).first {
            embedding = self.embedding(for: processedImage)
        }
        
        return embedding
    }
    
    private func embedding(for cgImage: CGImage) -> [Float]? {
        // Scale down the images to speed up processing and reduce feature details.
        let cgImage = fit(cgImage: cgImage, to: CGSize(width: 100, height: 100))
        
        // Perform feature detection
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            return nil
        }

        // Access the feature data
        let data = observation.data
        guard data.isEmpty == false else {
            return nil
        }

        // Determine the element type and size
        let elementType = observation.elementType
        let elementCount = observation.elementCount
        let typeSize = VNElementTypeSize(elementType)
        var embedding: [Float]?
        
        // Handle the different element types
        switch elementType {
        case .float where typeSize == MemoryLayout<Float>.size:
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                let buffer = bytes.bindMemory(to: Float.self)
                if buffer.count == elementCount {
                    embedding = buffer.map { $0 }
                }
            }
        default:
            print("Unsupported VNElementType: \(elementType)")
            return nil
        }

        return embedding
    }
    

    
    // MARK: - Image Processing
    
    func process(cgImage: CGImage, attention: Attention) -> [CGImage] {
        var processedImages = [CGImage]()
        
        switch attention {
        case .none:
            processedImages.append(cgImage)
        case .saliency(let saliency):
            let processedImage = cropToSalientRegion(cgImage: cgImage, saliency: saliency)
            processedImages.append(processedImage)
        case .foreground:
            let processedImage = segmentForegroundSubjects(cgImage: cgImage)
            processedImages.append(processedImage)
        case .faces:
            let faceImages = cropToFaces(cgImage: cgImage)
            processedImages.append(contentsOf: faceImages)
        case .zoom(let factors):
            let zoomedImages = zoom(cgImage: cgImage, factors: factors)
            processedImages.append(contentsOf: zoomedImages)
        }
        
        return processedImages
    }
    
    private func cropToSalientRegion(cgImage: CGImage, saliency: Attention.Saliency) -> CGImage {
        // Perform saliency detection
        let request: VNImageBasedRequest
        switch saliency {
        case .attention: request = VNGenerateAttentionBasedSaliencyImageRequest()
        case .objectness: request = VNGenerateObjectnessBasedSaliencyImageRequest()
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return cgImage
        }

        // Get the salient objects
        guard let observation = request.results?.first as? VNSaliencyImageObservation,
              let salientObject = observation.salientObjects?.first else
        {
            // No salient object detected, crop to the center square
            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            let sideLength = min(imageSize.width, imageSize.height)
            let centerRect = CGRect(
                x: (imageSize.width - sideLength) / 2,
                y: (imageSize.height - sideLength) / 2,
                width: sideLength,
                height: sideLength
            )
            
            return cgImage.cropping(to: centerRect) ?? cgImage
        }

        // Get the bounding box of the salient object and convert the bounding box
        // from Vision normalized coordinates to CoreGraphics coordinates
        let boundingBox = salientObject.boundingBox
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var salientRect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
        // Outset by a margin making the rect slightly larger
        salientRect = salientRect.insetBy(dx: -16, dy: -16)

        // Crop the image to the salient region
        return cgImage.cropping(to: salientRect) ?? cgImage
    }
    
    private func segmentForegroundSubjects(cgImage: CGImage) -> CGImage {
        // Perform foreground subject detection
        let requst = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([requst])
        } catch {
            return cgImage
        }
        
        // Generate a masked image of the foreground subjects
        let foregroundSubjectsImage: CGImage
        if let result = requst.results?.first {
            let maskedImagePixelBuffer = try! result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )
            let ciContext = CIContext()
            let ciImage = CIImage(cvPixelBuffer: maskedImagePixelBuffer)
            
            foregroundSubjectsImage = ciContext.createCGImage(ciImage, from: ciImage.extent) ?? cgImage
        } else {
            foregroundSubjectsImage = cgImage
        }
        
        return foregroundSubjectsImage
    }
    
    private func cropToFaces(cgImage: CGImage) -> [CGImage] {
        // Perform face detection
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
        } catch {
            return [cgImage]
        }
        
        // Extract face regions
        guard let observations = request.results else {
            return []
        }
        
        let faceImages = observations.compactMap { observation in
            // Convert the bounding box from Vision coordinates to image coordinates
            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            let boundingBox = observation.boundingBox
            let faceRect = CGRect(
                x: boundingBox.origin.x * imageSize.width,
                y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
                width: boundingBox.width * imageSize.width,
                height: boundingBox.height * imageSize.height
            )
            
            // Crop the CGImage to each face's bounding box
            return cgImage.cropping(to: faceRect)
        }
        
        return faceImages
    }
    
    private func zoom(cgImage: CGImage, factors: [CGFloat]) -> [CGImage] {
        var zommedImages = [CGImage]()
        
        for factor in factors {
            let zommedImage = zoom(cgImage: cgImage, factor: factor)
            zommedImages.append(zommedImage)
        }
        
        return zommedImages
    }
    
    private func zoom(cgImage: CGImage, factor: CGFloat) -> CGImage {
        guard factor > 1 else { return cgImage }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let initialRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
        
        // Inset based on zoom factor
        let dx = imageSize.width * (1 - (1 / factor)) / 2
        let dy = imageSize.height * (1 - (1 / factor)) / 2
        let zoomedRect = initialRect.insetBy(dx: dx, dy: dy)
        
        return cgImage.cropping(to: zoomedRect) ?? cgImage
    }
    
    private func fit(cgImage: CGImage, to targetSize: CGSize) -> CGImage {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Calculate the aspect ratios and scale factor
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scaleFactor = min(widthRatio, heightRatio)

        // Construct the scaled rect
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        let offsetX = (targetSize.width - scaledWidth) / 2.0 // Center horizontally
        let offsetY = (targetSize.height - scaledHeight) / 2.0 // Center vertically
        let scaledRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        
        // Use a scale of 1 so the pixels match the target size
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let fitImage = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: scaledRect)
        }
        
        return fitImage.cgImage ?? cgImage
    }
}
