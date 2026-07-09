import SwiftUI

struct DraggableImageView: View {
    let minimumImageScale: CGFloat = 0.25
    let maximumImageScale: CGFloat = 6.0
    let dragActivationThreshold: CGFloat = 4
    let scaleActivationThreshold: CGFloat = 0.02
    let rotationActivationThreshold: CGFloat = 0.03

    @Binding var item: CanvasImage
    @Binding var selectedFilter: Filter
    @Binding var selectedImageID: UUID?
    @Binding var activeInteractionImageID: UUID?
    @Binding var backgroundRemovalImageID: UUID?
    var canvasSize: CGSize
    var onLongPress: (CGPoint) -> Void
    var onInteractionStart: () -> Void
    var onInteractionBegan: () -> Void
    var onInteractionEnded: () -> Void
    @State private var isInteracting = false
    @State private var transientPosition: CGPoint?
    @State private var transientScale: CGFloat?
    @State private var transientRotation: Double?
    @State private var filteredImage: CGImage?
    @State private var isProcessing = false

    private var displayedPosition: CGPoint {
        transientPosition ?? item.element.position
    }

    private var displayedScale: CGFloat {
        transientScale ?? CGFloat(item.element.scale)
    }

    private var displayedRotation: Double {
        transientRotation ?? item.element.rotation
    }

    var displayedImageSize: CGSize {
        aspectFitSize(
            for: item.image.size,
            in: CGSize(width: item.element.width, height: item.element.height)
        )
    }

    var effectiveZIndex: Double {
        isInteracting ? 10_000 : Double(item.element.zIndex)
    }

    var isSelected: Bool {
        selectedImageID == item.element.id
    }

    var isBackgroundRemoving: Bool {
        backgroundRemovalImageID == item.element.id
    }

    var body: some View {
        let combinedGesture = DragGesture()
            .simultaneously(with: MagnificationGesture())
            .simultaneously(with: RotationGesture())
            .onChanged { value in
                if let activeInteractionImageID, activeInteractionImageID != item.element.id {
                    return
                }

                let drag = value.first?.first
                let magnify = value.first?.second
                let rotate = value.second
                if selectedImageID != item.element.id {
                    selectedImageID = item.element.id
                }

                let hasMeaningfulDrag = drag.map {
                    abs($0.translation.width) > dragActivationThreshold ||
                    abs($0.translation.height) > dragActivationThreshold
                } ?? false
                let hasMeaningfulScale = magnify.map {
                    abs($0 - 1) > scaleActivationThreshold
                } ?? false
                let hasMeaningfulRotation = rotate.map {
                    abs($0.radians) > rotationActivationThreshold
                } ?? false

                if hasMeaningfulDrag || hasMeaningfulScale || hasMeaningfulRotation {
                    if activeInteractionImageID == nil {
                        activeInteractionImageID = item.element.id
                    }
                    if !isInteracting {
                        onInteractionBegan()
                        onInteractionStart()
                    }
                    isInteracting = true
                }

                let isTransforming = hasMeaningfulScale || hasMeaningfulRotation

                if let drag = drag, !isTransforming {
                    let proposedPosition = CGPoint(
                        x: item.lastPosition.width + drag.translation.width,
                        y: item.lastPosition.height + drag.translation.height
                    )
                    transientPosition = clampedPosition(
                        proposedPosition,
                        scale: displayedScale
                    )
                }

                if let magnify = magnify {
                    let nextScale = item.lastScale * magnify
                    let clampedNextScale = clampedScale(nextScale)
                    transientScale = clampedNextScale
                    transientPosition = clampedPosition(
                        displayedPosition,
                        scale: clampedNextScale
                    )
                }

                if let rotate = rotate {
                    transientRotation = item.lastRotation.radians + rotate.radians
                }
            }
            .onEnded { _ in
                let wasInteracting = isInteracting
                isInteracting = false
                if activeInteractionImageID == item.element.id {
                    activeInteractionImageID = nil
                }
                let settledScale = clampedScale(displayedScale)
                item.element.position = clampedPosition(
                    displayedPosition,
                    scale: settledScale
                )
                item.lastPosition = CGSize(
                    width: item.element.position.x,
                    height: item.element.position.y
                )
                item.lastScale = settledScale
                item.element.scale = Double(item.lastScale)
                item.element.rotation = displayedRotation
                item.lastRotation = Angle(radians: item.element.rotation)
                transientPosition = nil
                transientScale = nil
                transientRotation = nil

                if wasInteracting {
                    onInteractionEnded()
                }
            }

        let longPressGesture = LongPressGesture(minimumDuration: 0.45)
            .onEnded { _ in
                guard activeInteractionImageID == nil || activeInteractionImageID == item.element.id else {
                    return
                }
                isInteracting = false
                selectedImageID = item.element.id
                onLongPress(menuAnchorPoint)
            }

        ZStack {
            if item.element.borderWidth > 0 {
                SubjectBorderView(
                    image: item.image,
                    size: displayedImageSize,
                    color: item.element.borderColor.color,
                    lineWidth: CGFloat(item.element.borderWidth)
                )
                .scaleEffect(displayedScale)
                .rotationEffect(Angle(radians: displayedRotation))
            }

//            Image(uiImage: item.image)
//                .resizable()
//                .frame(width: displayedImageSize.width, height: displayedImageSize.height)
//                .colorMultiply(
//                    (item.element.elementFilter ?? .original).previewColor
//                )
//                .scaleEffect(CGFloat(item.element.scale))
//                .rotationEffect(Angle(radians: item.element.rotation))
            Group {
                if let filtered = filteredImage {
                    Image(decorative: filtered, scale: item.image.scale, orientation: .up)
                        .resizable()
                } else {
                    Image(uiImage: item.image)
                        .resizable()
                }
            }
            .id(imageRenderID)
            .frame(width: displayedImageSize.width, height: displayedImageSize.height)
            .scaleEffect(displayedScale)
            .rotationEffect(Angle(radians: displayedRotation))
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.25)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        ProgressView()
                            .tint(.white)
                    }
                    .frame(width: displayedImageSize.width, height: displayedImageSize.height)
                }
            }
            .task(id: imageProcessingID) {
                let currentFilter = item.element.elementFilter ?? .original
                guard currentFilter != .original else {
                    filteredImage = nil
                    item.cachedFilteredImage = nil
                    return
                }
                isProcessing = true
                guard let sourceCG = item.image.cgImage else {
                    isProcessing = false
                    return
                }
                
                if currentFilter == .watercolor || currentFilter == .sketch {
                    do {
                        let resultImg = try await AIFilterService.shared.applyFilter(image: item.image, filter: currentFilter)
                        filteredImage = resultImg.cgImage
                        item.cachedFilteredImage = resultImg
                    } catch {
                        print("AI Filter API call failed: \(error). Falling back to local filter.")
                        let processor = ImageFilterProcessor()
                        let result: CGImage = await processor.apply(currentFilter, to: sourceCG)
                        filteredImage = result
                        item.cachedFilteredImage = UIImage(cgImage: result)
                    }
                } else {
                    let processor = ImageFilterProcessor()
                    let result: CGImage = await processor.apply(currentFilter, to: sourceCG)
                    filteredImage = result
                    item.cachedFilteredImage = UIImage(cgImage: result)
                }
                isProcessing = false
            }

            if isBackgroundRemoving {
                processingBadge
                    .scaleEffect(displayedScale)
                    .rotationEffect(Angle(radians: displayedRotation))
            }

            if isSelected {
                selectionCorners
                    .frame(
                        width: displayedImageSize.width * displayedScale,
                        height: displayedImageSize.height * displayedScale
                    )
                    .rotationEffect(Angle(radians: displayedRotation))
            }
        }
        .frame(
            width: displayedImageSize.width * displayedScale,
            height: displayedImageSize.height * displayedScale
        )
        .contentShape(Rectangle())
        .position(
            x: canvasSize.width / 2 + displayedPosition.x,
            y: canvasSize.height / 2 + displayedPosition.y
        )
        .zIndex(effectiveZIndex)
        .highPriorityGesture(longPressGesture)
        .simultaneousGesture(combinedGesture)
        .onTapGesture {
            guard activeInteractionImageID == nil || activeInteractionImageID == item.element.id else {
                return
            }
            selectedImageID = item.element.id
        }
    }
}
