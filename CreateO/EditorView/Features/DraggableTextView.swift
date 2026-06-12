import SwiftUI

struct DraggableTextView: View {
    private let dragActivationThreshold: CGFloat = 4

    @Binding var item: CanvasText
    @Binding var selectedTextID: UUID?
    @FocusState.Binding var focusedTextID: UUID?
    let canvasSize: CGSize
    let onLongPress: () -> Void
    let onInteractionBegan: () -> Void
    let onInteractionEnded: () -> Void

    @State private var transientPosition: CGSize?
    @State private var transientFontSize: CGFloat?
    @State private var transientRotation: Angle?
    @State private var didStartInteraction = false

    var body: some View {
        let gesture = DragGesture()
            .simultaneously(with: MagnificationGesture())
            .simultaneously(with: RotationGesture())
            .onChanged { value in
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
                    onInteractionBegan()
                }

                if let drag = drag {
                    if hasMeaningfulDrag {
                        selectedTextID = item.id
                        focusedTextID = nil
                    }
                    transientPosition = CGSize(
                        width: item.lastPosition.width + drag.translation.width,
                        height: item.lastPosition.height + drag.translation.height
                    )
                }

                if let magnify = magnify {
                    transientFontSize = max(16, item.lastFontSize * magnify)
                }

                if let rotate = rotate {
                    transientRotation = item.lastRotation + rotate
                }
            }
            .onEnded { _ in
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

        TextField("", text: $item.text)
            .font(.custom(item.fontName, size: transientFontSize ?? item.fontSize))
            .foregroundStyle(item.textColor)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedTextID == item.id ? Color.white.opacity(0.18) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selectedTextID == item.id ? Color.accentColor : Color.clear, lineWidth: 1.5)
            }
            .rotationEffect(transientRotation ?? item.rotation)
            .position(
                x: canvasSize.width / 2 + (transientPosition ?? item.position).width,
                y: canvasSize.height / 2 + (transientPosition ?? item.position).height
            )
            .focused($focusedTextID, equals: item.id)
            .highPriorityGesture(gesture)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        selectedTextID = item.id
                        focusedTextID = nil
                        onLongPress()
                    }
            )
            .onTapGesture {
                if selectedTextID == item.id {
                    focusedTextID = item.id
                } else {
                    selectedTextID = item.id
                    focusedTextID = nil
                }
            }
    }
}
