import SwiftUI

struct Sticker: View {
    @State private var selectedTab: StickerTab = .recent
    @Binding var savedStickers: [UIImage]
    @Binding var selectedSticker: UIImage?
    @Binding var recentStickers: [UIImage]
    @Binding var selectedEmoji: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Sticker")
                .font(.headline.weight(.semibold))
                .padding(.top, 12)

            Picker("Sticker Category", selection: $selectedTab) {
                Label("Recent", systemImage: "clock")
                    .tag(StickerTab.recent)
                Label("New", systemImage: "photo.circle")
                    .tag(StickerTab.newSticker)
                Label("Emoji", systemImage: "face.smiling")
                    .tag(StickerTab.emojis)
                Label("Shapes", systemImage: "square.on.circle")
                    .tag(StickerTab.shapes)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)

            Group {
                switch selectedTab {
                case .recent:
                    recent(recentStickers: recentStickers, selectedSticker: $selectedSticker)
                case .newSticker:
                    newSticker(savedStickers: $savedStickers, selectedSticker: $selectedSticker)
                case .emojis:
                    emojis(selectedEmoji: $selectedEmoji)
                case .shapes:
                    shapes(selectedSticker: $selectedSticker)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    Sticker(savedStickers: .constant([]), selectedSticker: .constant(nil), recentStickers: .constant([]), selectedEmoji: .constant(nil))
}
