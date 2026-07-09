import Foundation
import PencilKit
import SwiftUI
import UIKit

extension EditorView {
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
                isBold: savedText.isBold,
                isItalic: savedText.isItalic,
                isUnderlined: savedText.isUnderlined,
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
                isBold: item.isBold,
                isItalic: item.isItalic,
                isUnderlined: item.isUnderlined,
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
