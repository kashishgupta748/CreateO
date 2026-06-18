import SwiftUI

extension EditorView {
    var selectedTextIndex: Int? {
        guard let selectedTextID else { return nil }
        return canvasTexts.firstIndex(where: { $0.id == selectedTextID && $0.isVisible })
    }

    var selectedTextStyleBinding: (fontName: String, textColor: Color)? {
        guard let index = selectedTextIndex else { return nil }
        return (canvasTexts[index].fontName, canvasTexts[index].textColor)
    }

    func syncSelectedTextSizeDraft() {
        guard let index = selectedTextIndex else {
            isEditingTextSize = false
            return
        }

        if !isEditingTextSize {
            selectedTextSizeDraft = Double(canvasTexts[index].fontSize)
        }
    }

    func addTextLayer() {
        isFilterActive = false
        isBrushActive = false
        dismissImageActions()
        selectedImageID = nil

        performHistoryChange {
            var textItem = CanvasText(
                text: "Text",
                fontName: UIFont.preferredFont(forTextStyle: .title2).fontName,
                fontSize: 34,
                textColor: .black,
                zIndex: nextAvailableLayerZIndex(),
                isVisible: true,
                lastFontSize: 34
            )
            textItem.position = .zero
            textItem.lastPosition = .zero

            canvasTexts.append(textItem)
            selectedTextID = textItem.id
            focusedTextID = textItem.id
            selectedTextSizeDraft = Double(textItem.fontSize)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guideManager.advance(from: .editorText)
        }
    }

    func addEmojiToCanvas(_ emoji: String) {
        isFilterActive = false
        isBrushActive = false
        dismissImageActions()
        selectedImageID = nil

        // Render emoji → UIImage so it behaves like a sticker:
        // pinch-to-zoom works, no text-style popup appears
        let renderSize: CGFloat = 200
        let canvasSize: CGFloat = 120
        let image = renderEmojiImage(emoji, size: renderSize)

        performHistoryChange {
            let element = Element(
                id: UUID(),
                elementType: .emojis,
                x: 0,
                y: 0,
                height: canvasSize,
                width: canvasSize,
                elementPath: "",
                elementFilter: .original,
                zIndex: nextAvailableLayerZIndex()
            )
            canvasImages.append(CanvasImage(image: image, element: element))
            selectedImageID = element.id
            showSheet = false
            // addToRecent() intentionally NOT called for emojis
        }
    }

    private func renderEmojiImage(_ emoji: String, size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let font = UIFont.systemFont(ofSize: size * 0.80)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let str = emoji as NSString
            let textSize = str.size(withAttributes: attrs)
            let origin = CGPoint(x: (size - textSize.width) / 2,
                                 y: (size - textSize.height) / 2)
            str.draw(at: origin, withAttributes: attrs)
        }
    }

    func removeTextLayerIfEmpty(_ textID: UUID) {
        guard let index = canvasTexts.firstIndex(where: { $0.id == textID }) else { return }
        guard canvasTexts[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        performHistoryChange {
            if selectedTextID == textID {
                selectedTextID = nil
            }
            if focusedTextID == textID {
                focusedTextID = nil
            }
            if textActionTargetID == textID {
                textActionTargetID = nil
                showTextActionMenu = false
            }

            canvasTexts.remove(at: index)
        }
    }

    func presentTextActions(for textID: UUID) {
        selectedTextID = textID
        textActionTargetID = textID
        showImageActionMenu = false
        showBrushActionMenu = false
        isBrushActive = false
        isFilterActive = false
        focusedTextID = nil
        showTextActionMenu = true
    }

    func duplicateSelectedText() {
        guard let targetID = textActionTargetID,
              let text = canvasTexts.first(where: { $0.id == targetID }) else { return }

        performHistoryChange {
            showTextActionMenu = false
            focusedTextID = nil

            var duplicatedText = CanvasText(
                text: text.text,
                fontName: text.fontName,
                fontSize: text.fontSize,
                textColor: text.textColor,
                zIndex: nextAvailableLayerZIndex(),
                isVisible: text.isVisible,
                lastFontSize: text.fontSize
            )
            duplicatedText.position = CGSize(width: text.position.width + 24, height: text.position.height + 24)
            duplicatedText.lastPosition = duplicatedText.position
            duplicatedText.lastRotation = text.rotation
            duplicatedText.rotation = text.rotation

            canvasTexts.append(duplicatedText)
            textActionTargetID = duplicatedText.id
            selectedTextID = duplicatedText.id
        }
    }

    func deleteSelectedText() {
        guard let targetID = textActionTargetID else { return }

        performHistoryChange {
            showTextActionMenu = false
            focusedTextID = nil
            if selectedTextID == targetID {
                selectedTextID = nil
            }
            textActionTargetID = nil
            canvasTexts.removeAll { $0.id == targetID }
        }
    }

    func toggleTextLayerVisibility(_ textID: UUID) {
        guard let index = canvasTexts.firstIndex(where: { $0.id == textID }) else { return }
        performHistoryChange {
            canvasTexts[index].isVisible.toggle()
            if !canvasTexts[index].isVisible, selectedTextID == textID {
                selectedTextID = nil
                focusedTextID = nil
            }
        }
    }

    func selectTextLayer(_ textID: UUID) {
        guard canvasTexts.contains(where: { $0.id == textID && $0.isVisible }) else { return }
        dismissImageActions()
        selectedImageID = nil
        selectedTextID = textID
        focusedTextID = nil
        syncSelectedTextSizeDraft()
    }

    func applySelectedTextFont(_ fontName: String) {
        guard let index = selectedTextIndex else { return }
        guard canvasTexts[index].fontName != fontName else { return }

        performHistoryChange {
            canvasTexts[index].fontName = fontName
        }

        guideManager.advance(from: .editorText)
    }

    func applySelectedTextColor(_ color: Color) {
        guard let index = selectedTextIndex else { return }
        let incomingColor = SavedColor(color)
        let existingColor = SavedColor(canvasTexts[index].textColor)
        guard incomingColor != existingColor else { return }

        performHistoryChange {
            canvasTexts[index].textColor = color
        }

        guideManager.advance(from: .editorText)
    }

    func beginTextSizeEditing() {
        guard selectedTextIndex != nil else { return }
        guard !isEditingTextSize else { return }

        isEditingTextSize = true
        beginHistoryTransaction()
    }

    func previewSelectedTextSize(_ size: Double) {
        guard let index = selectedTextIndex else { return }

        let clampedSize = min(max(size, 16), 120)
        selectedTextSizeDraft = clampedSize
        canvasTexts[index].fontSize = CGFloat(clampedSize)
        canvasTexts[index].lastFontSize = CGFloat(clampedSize)
        guideManager.advance(from: .editorText)
    }

    func commitTextSizeEditing() {
        guard isEditingTextSize else { return }
        isEditingTextSize = false
        endHistoryTransaction()
    }
}
