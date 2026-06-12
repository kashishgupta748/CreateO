import Foundation
import CoreImage
import PencilKit
import PhotosUI
import SwiftUI
import Vision
import VisionKit

extension EditorView {
    func replaceImage(_ image: UIImage, for imageID: UUID) {
        guard let index = canvasImages.firstIndex(where: { $0.element.id == imageID }) else { return }

        performHistoryChange {
            canvasImages[index].image = image
        }
    }

    func applyCropImage(_ croppedImage: UIImage) {
        guard let imageActionTargetID else { return }
        replaceImage(croppedImage, for: imageActionTargetID)
    }

    @MainActor
    func removeBackgroundFromSelectedImage() {
        guard let imageActionTargetID,
              let sourceImage = selectedCanvasImage?.image else { return }
        let processingImage = sourceImage.normalizedForEditing()?.downscaledForProcessing() ?? sourceImage

        backgroundRemovalImageID = imageActionTargetID
        selectedImageID = imageActionTargetID
        dismissImageActions()

        Task.detached(priority: .userInitiated) {
            let liftedImage = await Self.backgroundRemovedImage(from: processingImage)
            guard let liftedImage else {
                await MainActor.run {
                    backgroundRemovalImageID = nil
                }
                return
            }

            await MainActor.run {
                replaceImage(liftedImage, for: imageActionTargetID)
                selectedImageID = imageActionTargetID
                backgroundRemovalImageID = nil
                guideManager.advance(from: .removeBackground)
            }
        }
    }

    static func backgroundRemovedImage(from image: UIImage) async -> UIImage? {
        if let cutout = visionForegroundCutout(from: image) {
            return cutout
        }

        return await subjectLiftedImage(from: image)
    }

    @MainActor
    static func subjectLiftedImage(from image: UIImage) async -> UIImage? {
        guard ImageAnalyzer.isSupported,
              let normalized = image.normalizedForEditing() else { return nil }

        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([.visualLookUp])

        do {
            let analysis = try await analyzer.analyze(normalized, configuration: configuration)
            let interaction = ImageAnalysisInteraction()
            interaction.analysis = analysis
            interaction.preferredInteractionTypes = .imageSubject

            let hostView = UIImageView(image: normalized)
            hostView.addInteraction(interaction)

            let subjects = await interaction.subjects
            guard let primarySubject = subjects.max(by: { subjectArea($0) < subjectArea($1) }) else {
                return nil
            }

            return try await primarySubject.image
        } catch {
            return nil
        }
    }

    static func visionForegroundCutout(from image: UIImage) -> UIImage? {
        guard let normalized = image.normalizedForEditing(),
              let cgImage = normalized.cgImage else { return nil }

        return autoreleasepool {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest()

            do {
                try requestHandler.perform([request])
                guard let observation = request.results?.first,
                      !observation.allInstances.isEmpty,
                      let maskBuffer = try? observation.generateScaledMaskForImage(
                        forInstances: observation.allInstances,
                        from: requestHandler
                      ) else {
                    return nil
                }

                let sourceImage = CIImage(cgImage: cgImage)
                let maskImage = CIImage(cvPixelBuffer: maskBuffer)
                    .transformed(by: CGAffineTransform(
                        scaleX: sourceImage.extent.width / CGFloat(CVPixelBufferGetWidth(maskBuffer)),
                        y: sourceImage.extent.height / CGFloat(CVPixelBufferGetHeight(maskBuffer))
                    ))

                let context = CIContext(options: [.cacheIntermediates: false])
                let transparentBackground = CIImage(color: .clear).cropped(to: sourceImage.extent)

                guard let alphaMasked = CIFilter(
                    name: "CIBlendWithAlphaMask",
                    parameters: [
                        kCIInputImageKey: sourceImage,
                        kCIInputBackgroundImageKey: transparentBackground,
                        kCIInputMaskImageKey: maskImage
                    ]
                )?.outputImage?.cropped(to: sourceImage.extent),
                      let outputCGImage = context.createCGImage(alphaMasked, from: alphaMasked.extent) else {
                    return nil
                }

                let cutout = UIImage(cgImage: outputCGImage, scale: normalized.scale, orientation: .up)
                return cutout.croppedToVisibleAlphaBounds(padding: 12) ?? cutout
            } catch {
                return nil
            }
        }
    }

    @MainActor
    static func subjectArea(_ subject: ImageAnalysisInteraction.Subject) -> CGFloat {
        subject.bounds.width * subject.bounds.height
    }

    func clampedImageActionMenuPosition(for point: CGPoint) -> CGPoint {
        let menuWidth: CGFloat = 292
        let menuHeight: CGFloat = 250
        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 18

        return CGPoint(
            x: min(max(point.x, menuWidth / 2 + horizontalPadding), currentCanvasSize.width - menuWidth / 2 - horizontalPadding),
            y: min(max(point.y, menuHeight / 2 + verticalPadding), currentCanvasSize.height - menuHeight / 2 - verticalPadding)
        )
    }

    func addCanvasImages(_ images: [UIImage], shouldRecordHistory: Bool = true) {
        guard !images.isEmpty else { return }

        let addImages = {
            for image in images {
                let defaultWidth = max(currentCanvasSize.width * 0.82, 220)
                let defaultHeight = max(currentCanvasSize.height * 0.82, 260)
                let element = Element(
                    id: UUID(),
                    elementType: .image,
                    x: 0,
                    y: 0,
                    scale: 1.0,
                    rotation: 0,
                    height: defaultHeight,
                    width: defaultWidth,
                    elementPath: "temp",
                    elementFilter: .original,
                    zIndex: nextAvailableLayerZIndex()
                )

                canvasImages.append(
                    CanvasImage(
                        image: image,
                        element: element,
                        lastPosition: CGSize(width: element.position.x, height: element.position.y),
                        lastScale: CGFloat(element.scale),
                        lastRotation: Angle(radians: element.rotation)
                    )
                )
            }
        }

        if shouldRecordHistory {
            performHistoryChange(addImages)
        } else {
            addImages()
        }

        guideManager.advance(from: .uploadPhoto)
    }

    func handleSelectedItems(_ newItems: [PhotosPickerItem]) {
        for item in newItems {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let canvasImage = image.downscaledForCanvas() ?? image.normalizedForEditing() ?? image
                    await MainActor.run {
                        addCanvasImages([canvasImage])
                    }
                }
            }
        }
    }

    func saveDesign(
        in designStore: DataStore,
        dismiss: DismissAction,
        destination: EditorSaveDestination
    ) {
        brushHasContent = !drawingCanvas.drawing.strokes.isEmpty
        guard let renderedImage = renderCanvasImage() else { return }

        let existingDesign = editingDesign.flatMap { design in
            designStore.designs.first(where: { $0.id == design.id }) ?? design
        }
        let designID = existingDesign?.id ?? UUID()

        guard let previewPath = persistPreviewImage(
                renderedImage,
                id: designID,
                replacing: existingDesign?.designPath
              ),
              let projectPath = persistProjectState(for: designID) else {
            return
        }

        let trimmedName = designName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? (existingDesign?.designName ?? "Untitled") : trimmedName

        let albumID: UUID?
        if let existingDesign {
            albumID = existingDesign.albumID
        } else {
            switch destination {
            case .library:
                albumID = nil
            case .existingAlbum(let existingAlbumID):
                albumID = existingAlbumID
            case .newAlbum:
                albumID = nil
            }
        }

        let savedDesign = Design(
            id: designID,
            designName: resolvedName,
            createdAt: existingDesign?.createdAt ?? Date(),
            updatedAt: existingDesign == nil ? nil : Date(),
            isFavorite: existingDesign?.isFavorite ?? false,
            designType: .image,
            designHeight: existingDesign?.designHeight ?? 270,
            designWidth: existingDesign?.designWidth ?? 180,
            designPath: previewPath,
            thumbnailPath: previewPath,
            albumID: albumID,
            projectPath: projectPath
        )

        if existingDesign != nil {
            designStore.updateDesign(design: savedDesign)
        } else {
            designStore.designs.insert(savedDesign, at: 0)

            switch destination {
            case .library:
                break
            case .existingAlbum(let existingAlbumID):
                designStore.addDesign(designID, toAlbum: existingAlbumID)
            case .newAlbum(let albumName):
                let createdAlbumID = designStore.createAlbum(named: albumName, initialDesignIDs: [designID])
                if let index = designStore.designs.firstIndex(where: { $0.id == designID }) {
                    designStore.designs[index].albumID = createdAlbumID
                }
            }
        }
        
        //Fire background cloud sync for authenticated users - non blocking
        if authManager.isLoggedIn {
            let captured = savedDesign
            let capturedAuth = authManager
            Task.detached(priority: .background) {
                await designStore.uploadDesignToCloud(design: captured, authManager: capturedAuth)
            }
        }

        designName = ""
        selectedSaveAlbumID = nil
        newAlbumName = ""
        showSaveSheet = false
        dismiss()
    }

    func loadSavedProject(from projectPath: String) -> Bool {
        let projectDirectoryURL = URL(fileURLWithPath: projectPath, isDirectory: true)
        let projectFileURL = projectDirectoryURL.appendingPathComponent("project.json")

        guard let data = try? Data(contentsOf: projectFileURL),
              let savedProject = try? JSONDecoder().decode(SavedDesignProject.self, from: data) else {
            return false
        }

        canvasImages = savedProject.images.compactMap { savedImage in
            let imageURL = projectDirectoryURL.appendingPathComponent(savedImage.imageRelativePath)
            guard let image = UIImage(contentsOfFile: imageURL.path) else {
                return nil
            }

            return CanvasImage(
                image: image,
                element: savedImage.element,
                isVisible: savedImage.isVisible,
                lastPosition: CGSize(width: savedImage.element.position.x, height: savedImage.element.position.y),
                lastScale: CGFloat(savedImage.element.scale),
                lastRotation: Angle(radians: savedImage.element.rotation)
            )
        }

        canvasTexts = savedProject.texts.map { savedText in
            CanvasText(
                id: savedText.id,
                text: savedText.text,
                fontName: savedText.fontName,
                fontSize: CGFloat(savedText.fontSize),
                textColor: savedText.textColor.color,
                zIndex: savedText.zIndex,
                isVisible: savedText.isVisible,
                position: CGSize(width: savedText.positionX, height: savedText.positionY),
                rotation: Angle(radians: savedText.rotationRadians),
                lastPosition: CGSize(width: savedText.positionX, height: savedText.positionY),
                lastFontSize: CGFloat(savedText.fontSize),
                lastRotation: Angle(radians: savedText.rotationRadians)
            )
        }

        canvasColor = savedProject.canvasColor.color
        designName = savedProject.designName

        if let brushLayer = savedProject.brushLayer,
           let drawing = try? PKDrawing(data: brushLayer.drawingData) {
            drawingCanvas.drawing = drawing
            brushLayerZIndex = brushLayer.zIndex
            isBrushLayerVisible = brushLayer.isVisible
            brushHasContent = !drawing.strokes.isEmpty
        } else {
            drawingCanvas.drawing = PKDrawing()
            brushLayerZIndex = nextAvailableLayerZIndex()
            isBrushLayerVisible = true
            brushHasContent = false
        }

        return true
    }

    private func persistPreviewImage(_ image: UIImage, id: UUID, replacing existingPath: String?) -> String? {
        guard let data = image.pngData(),
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let fileURL = documentsDirectory.appendingPathComponent("design-\(id.uuidString)-preview-\(timestamp).png")
        try? data.write(to: fileURL, options: .atomic)

        if let existingPath {
            let existingURL = URL(fileURLWithPath: existingPath)
            if existingURL.path.hasPrefix(documentsDirectory.path), existingURL.path != fileURL.path {
                try? FileManager.default.removeItem(at: existingURL)
            }
        }

        return fileURL.path
    }

    private func persistProjectState(for id: UUID) -> String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let projectDirectoryURL = documentsDirectory.appendingPathComponent("design-\(id.uuidString)-project", isDirectory: true)
        if FileManager.default.fileExists(atPath: projectDirectoryURL.path) {
            try? FileManager.default.removeItem(at: projectDirectoryURL)
        }
        try? FileManager.default.createDirectory(at: projectDirectoryURL, withIntermediateDirectories: true)

        let savedImages: [SavedCanvasImage] = canvasImages.enumerated().compactMap { index, item in
            guard let data = item.image.pngData() else { return nil }
            let relativePath = "layer-\(index)-\(item.element.id.uuidString).png"
            let fileURL = projectDirectoryURL.appendingPathComponent(relativePath)
            try? data.write(to: fileURL, options: .atomic)

            var element = item.element
            element.elementPath = relativePath
            return SavedCanvasImage(
                imageRelativePath: relativePath,
                element: element,
                isVisible: item.isVisible
            )
        }

        let savedTexts = canvasTexts.map { item in
            SavedCanvasText(
                id: item.id,
                text: item.text,
                fontName: item.fontName,
                fontSize: Double(item.fontSize),
                textColor: SavedColor(item.textColor),
                zIndex: item.zIndex,
                isVisible: item.isVisible,
                positionX: item.position.width,
                positionY: item.position.height,
                rotationRadians: item.rotation.radians
            )
        }

        let brushLayer: SavedBrushLayer?
        if !drawingCanvas.drawing.strokes.isEmpty {
            brushLayer = SavedBrushLayer(
                drawingData: drawingCanvas.drawing.dataRepresentation(),
                zIndex: brushLayerZIndex,
                isVisible: isBrushLayerVisible
            )
        } else {
            brushLayer = nil
        }

        let savedProject = SavedDesignProject(
            designName: designName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : designName,
            canvasColor: SavedColor(canvasColor),
            images: savedImages,
            texts: savedTexts,
            brushLayer: brushLayer
        )

        let projectFileURL = projectDirectoryURL.appendingPathComponent("project.json")
        guard let projectData = try? JSONEncoder().encode(savedProject) else {
            return nil
        }

        try? projectData.write(to: projectFileURL, options: .atomic)
        return projectDirectoryURL.path
    }
}

private extension UIImage {
    func croppedToVisibleAlphaBounds(alphaThreshold: UInt8 = 8, padding: CGFloat = 0) -> UIImage? {
        guard let cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        let bytesPerRow = cgImage.bytesPerRow
        let alphaInfo = cgImage.alphaInfo

        guard alphaInfo != .none,
              alphaInfo != .noneSkipFirst,
              alphaInfo != .noneSkipLast else {
            return nil
        }

        let alphaIndex: Int
        switch alphaInfo {
        case .premultipliedFirst, .first, .noneSkipFirst:
            alphaIndex = 0
        default:
            alphaIndex = min(bytesPerPixel - 1, 3)
        }

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let row = bytes + (y * bytesPerRow)
            for x in 0..<width {
                let alpha = row[(x * bytesPerPixel) + alphaIndex]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let pixelPadding = Int(ceil(padding * scale))
        let cropMinX = max(minX - pixelPadding, 0)
        let cropMinY = max(minY - pixelPadding, 0)
        let cropMaxX = min(maxX + pixelPadding, width - 1)
        let cropMaxY = min(maxY + pixelPadding, height - 1)
        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}
