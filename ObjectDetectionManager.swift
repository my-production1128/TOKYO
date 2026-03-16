import PhotosUI
import Vision
import CoreML

struct TargetItemData: Identifiable, Codable {
    let id: UUID
    let label: String
    let croppedImageData: Data
    var isFound: Bool
}

struct CollectionItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let imageData: Data
    let targets: [TargetItemData]
}

class CollectionStore: ObservableObject {
    @Published var items: [CollectionItem] = [] {
        didSet { saveToDisk() }
    }

    private let savePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ISPY_Collections.json")

    init() { loadFromDisk() }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: savePath, options: [.atomic, .completeFileProtection])
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: savePath)
            items = try JSONDecoder().decode([CollectionItem].self, from: data)
        } catch {
            print("First launch, or no saved data.")
        }
    }
}

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let boundingBox: CGRect
    let confidence: Float
}

struct TargetItem: Identifiable {
    let id = UUID()
    let label: String
    let croppedImage: UIImage
    let boundingBox: CGRect
    var isFound: Bool = false
}

@MainActor
class ObjectDetectionManager: ObservableObject {
    @Published var detectedObjects: [DetectedObject] = []
    @Published var targetItems: [TargetItem] = []
    @Published var progress: Double = 0.0
    @Published var isAnalyzing: Bool = false

    func performDetection(in image: UIImage, targetCount: Int) {
        self.isAnalyzing = true
        self.progress = 0.0
        self.detectedObjects = []
        self.targetItems = []

        guard let modelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodelc") else {
            print("Error: AI model not found.")
            self.isAnalyzing = false
            return
        }

        guard let ciImage = CIImage(image: image) else {
            self.isAnalyzing = false
            return
        }
        let orientation = self.getCGImagePropertyOrientation(image.imageOrientation)

        Task.detached(priority: .userInitiated) {
            do {
                let coreMLModel = try MLModel(contentsOf: modelURL)
                let visionModel = try VNCoreMLModel(for: coreMLModel)

                var regions: [CGRect] = [CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)]
                let mediumPositions: [CGFloat] = [0.0, 0.4]
                for y in mediumPositions {
                    for x in mediumPositions { regions.append(CGRect(x: x, y: y, width: 0.6, height: 0.6)) }
                }
                regions.append(CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6))

                let smallPositions: [CGFloat] = [0.0, 0.3, 0.6]
                for y in smallPositions {
                    for x in smallPositions { regions.append(CGRect(x: x, y: y, width: 0.4, height: 0.4)) }
                }

                var allSafeResults: [(label: String, boundingBox: CGRect, confidence: Float)] = []
                let total = regions.count

                for (index, region) in regions.enumerated() {
                    let request = VNCoreMLRequest(model: visionModel)
                    request.imageCropAndScaleOption = .scaleFill
                    request.regionOfInterest = region

                    let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
                    try handler.perform([request])

                    if let observations = request.results as? [VNRecognizedObjectObservation] {
                        for obs in observations {
                            guard let top = obs.labels.first, top.confidence >= 0.3 else { continue }
                            let localBox = obs.boundingBox
                            let fullX = region.minX + localBox.minX * region.width
                            let fullY = region.minY + localBox.minY * region.height
                            let fullWidth = localBox.width * region.width
                            let fullHeight = localBox.height * region.height
                            let fullBox = CGRect(x: fullX, y: fullY, width: fullWidth, height: fullHeight)

                            allSafeResults.append((label: top.identifier, boundingBox: fullBox, confidence: top.confidence))
                        }
                    }

                    let currentProgress = Double(index + 1) / Double(total)
                    Task { @MainActor in self.progress = currentProgress }
                }

                Task { @MainActor in
                    self.processResultsWithNMS(allSafeResults, originalImage: image, targetCount: targetCount)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.isAnalyzing = false
                }

            } catch {
                print("Analysis execution error: \(error)")
                Task { @MainActor in self.isAnalyzing = false }
            }
        }
    }

    nonisolated private func getCGImagePropertyOrientation(_ uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up; case .down: return .down
        case .left: return .left; case .right: return .right
        case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private func computeIoU(_ boxA: CGRect, _ boxB: CGRect) -> CGFloat {
        let intersection = boxA.intersection(boxB)
        if intersection.isNull { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let areaA = boxA.width * boxA.height
        let areaB = boxB.width * boxB.height
        return intersectionArea / (areaA + areaB - intersectionArea)
    }

    private func processResultsWithNMS(_ tuples: [(label: String, boundingBox: CGRect, confidence: Float)], originalImage: UIImage, targetCount: Int) {
        let sortedTuples = tuples.sorted { $0.confidence > $1.confidence }
        var keptObjects: [DetectedObject] = []
        var labels: Set<String> = []

        for item in sortedTuples {
            var isDuplicate = false
            for kept in keptObjects {
                if computeIoU(item.boundingBox, kept.boundingBox) > 0.4 {
                    isDuplicate = true; break
                }
            }
            if !isDuplicate {
                keptObjects.append(DetectedObject(label: item.label, boundingBox: item.boundingBox, confidence: item.confidence))
                labels.insert(item.label)
            }
        }

        keptObjects.sort { ($0.boundingBox.width * $0.boundingBox.height) > ($1.boundingBox.width * $1.boundingBox.height) }
        self.detectedObjects = keptObjects

        if self.targetItems.isEmpty && !keptObjects.isEmpty {
            var selectedObjects: [DetectedObject] = []
            var usedLabels: Set<String> = []

            for obj in keptObjects.shuffled() {
                if !usedLabels.contains(obj.label) {
                    selectedObjects.append(obj)
                    usedLabels.insert(obj.label)
                    if selectedObjects.count == targetCount { break }
                }
            }

            if selectedObjects.count < targetCount {
                for obj in keptObjects.shuffled() {
                    if !selectedObjects.contains(where: { $0.id == obj.id }) {
                        selectedObjects.append(obj)
                        if selectedObjects.count == targetCount { break }
                    }
                }
            }

            var newTargetItems: [TargetItem] = []
            for obj in selectedObjects {
                if let cropped = cropImage(originalImage, boundingBox: obj.boundingBox) {
                    var finalImage = cropped
                    if #available(iOS 17.0, *) {
                        if let liftedImage = removeBackground(from: cropped) { finalImage = liftedImage }
                    }
                    newTargetItems.append(TargetItem(label: obj.label, croppedImage: finalImage, boundingBox: obj.boundingBox, isFound: false))
                }
            }
            self.targetItems = newTargetItems
        }
    }

    private func cropImage(_ image: UIImage, boundingBox: CGRect) -> UIImage? {
        let marginX = boundingBox.width * 0.05
        let marginY = boundingBox.height * 0.05
        let minX = max(0.0, boundingBox.minX - marginX)
        let minY = max(0.0, boundingBox.minY - marginY)
        let maxX = min(1.0, boundingBox.maxX + marginX)
        let maxY = min(1.0, boundingBox.maxY + marginY)

        let size = image.size
        let rect = CGRect(
            x: minX * size.width, y: (1.0 - maxY) * size.height,
            width: (maxX - minX) * size.width, height: (maxY - minY) * size.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }
    }

    @available(iOS 17.0, *)
    private func removeBackground(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return image }
            let allInstances = observation.allInstances
            if allInstances.isEmpty { return image }
            let maskedPixelBuffer = try observation.generateMaskedImage(ofInstances: allInstances, from: handler, croppedToInstancesExtent: false)
            let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            guard let finalCGImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return image }
            return UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
        } catch {
            return image
        }
    }
}
