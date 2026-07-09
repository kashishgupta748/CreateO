import SwiftUI

struct DraggableTextView: View {
    private let dragActivationThreshold: CGFloat = 4

    @Binding var item: CanvasText
    @Binding var selectedTextID: UUID?
    @FocusState.Binding var focusedTextID: UUID?
    let canvasSize: CGSize
    let onLongPress: () -> Void
    let onSelect: () -> Void
    let onInteractionBegan: () -> Void
    let onInteractionEnded: () -> Void
    let onRemoveIfEmpty: () -> Void

    @State private var transientPosition: CGSize?
    @State private var transientFontSize: CGFloat?
    @State private var transientRotation: Angle?
    @State private var didStartInteraction = false

    private var textBinding: Binding<String> {
        Binding(
            get: { item.text },
            set: { newValue in
                item.text = String(newValue.prefix(140))
            }
        )
    }

    private var isSelected: Bool {
        selectedTextID == item.id
    }

    private var isFocused: Bool {
        focusedTextID == item.id
    }

    private var displayText: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Text" : item.text
    }

    var body: some View {
        let gesture = DragGesture()
            .simultaneously(with: MagnificationGesture())
            .simultaneously(with: RotationGesture())
            .onChanged { value in
                guard !isFocused else { return }

                let drag = value.first?.first
                let magnify = value.first?.second
                let rotate = value.second

                let hasMeaningfulDrag = drag.map {
                    abs($0.translation.width) > dragActivationThreshold ||
                    abs($0.translation.height) > dragActivationThreshold
                } ?? false
                let hasMeaningfulScale = magnify.map { abs($0 - 1) > 0.02 } ?? false
                let hasMeaningfulRotation = rotate.map { abs($0.radians) > 0.03 } ?? false

                if (hasMeaningfulDrag || hasMeaningfulScale || hasMeaningfulRotation) && !didStartInteraction {
                    didStartInteraction = true
                    onSelect()
                    onInteractionBegan()
                }

                if let drag {
                    if hasMeaningfulDrag {
                        focusedTextID = nil
                    }
                    transientPosition = CGSize(
                        width: item.lastPosition.width + drag.translation.width,
                        height: item.lastPosition.height + drag.translation.height
                    )
                }

                if let magnify {
                    transientFontSize = max(16, item.lastFontSize * magnify)
                }

                if let rotate {
                    transientRotation = item.lastRotation + rotate
                }
            }
            .onEnded { _ in
                guard !isFocused else { return }

                let finalPosition = transientPosition ?? item.position
                let finalFontSize = transientFontSize ?? item.fontSize
                let finalRotation = transientRotation ?? item.rotation

                item.position = finalPosition
                item.fontSize = finalFontSize
                item.rotation = finalRotation
                item.lastPosition = finalPosition
                item.lastFontSize = finalFontSize
                item.lastRotation = finalRotation

                transientPosition = nil
                transientFontSize = nil
                transientRotation = nil

                if didStartInteraction {
                    onInteractionEnded()
                    didStartInteraction = false
                }
            }

        Group {
            if isFocused {
                TextField("Add text", text: textBinding, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .submitLabel(.done)
            } else {
                Text(displayText)
                    .frame(minWidth: 44)
            }
        }
        .font(Font(item.displayUIFont(fontSize: transientFontSize ?? item.fontSize)))
        .foregroundStyle(isFocused && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.textColor.opacity(0.45) : item.textColor)
        .underline(item.isUnderlined, color: item.textColor)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, isFocused ? 18 : 16)
        .padding(.vertical, isFocused ? 13 : 11)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(backgroundStyle)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderColor, style: StrokeStyle(lineWidth: borderLineWidth, dash: isFocused ? [] : (isSelected ? [7, 5] : [])))
        }
        .overlay {
            if isSelected && !isFocused {
                KeynoteTextSelectionOverlay(accentColor: item.textColor)
                    .padding(-8)
            }
        }
        .shadow(color: shadowColor, radius: isFocused ? 18 : 12, y: 6)
        .rotationEffect(transientRotation ?? item.rotation)
        .position(
            x: canvasSize.width / 2 + (transientPosition ?? item.position).width,
            y: canvasSize.height / 2 + (transientPosition ?? item.position).height
        )
        .focused($focusedTextID, equals: item.id)
        .textInputAutocapitalization(.sentences)
        .disableAutocorrection(false)
        .highPriorityGesture(gesture)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onSelect()
                    focusedTextID = nil
                    onLongPress()
                }
        )
        .onTapGesture(count: 2) {
            onSelect()
            focusedTextID = item.id
        }
        .onTapGesture {
            if isSelected && !isFocused {
                focusedTextID = item.id
            } else {
                onSelect()
            }
        }
        .onChange(of: isFocused) { _, newValue in
            guard !newValue else { return }
            onRemoveIfEmpty()
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(.regularMaterial)
        }
        if isSelected {
            return AnyShapeStyle(item.textColor.opacity(0.08))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var borderColor: Color {
        if isFocused {
            return Color.accentColor.opacity(0.95)
        }
        if isSelected {
            return Color.accentColor.opacity(0.85)
        }
        return .clear
    }

    private var borderLineWidth: CGFloat {
        isFocused ? 2 : (isSelected ? 1.6 : 0)
    }

    private var shadowColor: Color {
        if isFocused {
            return Color.black.opacity(0.14)
        }
        if isSelected {
            return Color.black.opacity(0.10)
        }
        return Color.black.opacity(0.03)
    }
}

private struct KeynoteTextSelectionOverlay: View {
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accentColor.opacity(0.16), lineWidth: 1)

                Group {
                    selectionHandle
                        .position(x: 6, y: 6)
                    selectionHandle
                        .position(x: proxy.size.width - 6, y: 6)
                    selectionHandle
                        .position(x: 6, y: proxy.size.height - 6)
                    selectionHandle
                        .position(x: proxy.size.width - 6, y: proxy.size.height - 6)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(6)
                    .background(.regularMaterial, in: Capsule())
                    .offset(x: 10, y: -12)
                    .opacity(proxy.size.width > 36 ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
    }

    private var selectionHandle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}
