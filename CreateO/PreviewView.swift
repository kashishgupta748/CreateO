import SwiftUI

struct PreviewView: View {
    let design: Design

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsheet = false
    @State private var showDeleteAlert = false
    @State private var selectedDesign: Design?
    @State private var goToEditor = false

    var currentDesign: Design {
        designStore.designs.first(where: { $0.id == design.id }) ?? design
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 24
            let verticalPadding: CGFloat = 32
            let maxWidth = max(geometry.size.width - horizontalPadding, 220)
            let maxHeight = max(geometry.size.height - verticalPadding, 320)
            let canvasWidth = min(maxWidth, maxHeight * EditorView.canvasAspectRatio)
            let canvasHeight = canvasWidth / EditorView.canvasAspectRatio

            VStack {
                Spacer(minLength: 16)

                DesignImageView(path: currentDesign.designPath)
                    .scaledToFit()
                    .frame(width: canvasWidth, height: canvasHeight)
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let newScale = lastScale * value.magnification
                                scale = min(max(newScale, 1.0), 4.0)
                            }
                            .onEnded { value in
                                let newScale = lastScale * value.magnification
                                lastScale = min(max(newScale, 1.0), 4.0)
                                scale = lastScale
                            }
                    )
                    .animation(.easeInOut, value: scale)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedDesign = currentDesign
                    goToEditor = true
                } label: {
                    Text("Edit")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                ShareLink(
                    item: URL(string: "https://yourapp.com/design/\(currentDesign.id)")!,
                    preview: SharePreview(
                        currentDesign.designName,
                        image: Image(uiImage: DesignImageLoader.image(for: currentDesign.thumbnailPath) ?? UIImage())
                    )
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    designStore.toggleFavorite(id: currentDesign.id)
                } label: {
                    Image(systemName: currentDesign.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(currentDesign.isFavorite ? .red : .primary)
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    showsheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }

            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .navigationDestination(isPresented: $goToEditor) {
            EditorView(editingDesign: currentDesign)
        }
        .alert("Delete Design?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                let designToDelete = currentDesign
                dismiss()
                Task { @MainActor in
                    designStore.deleteDesign(design: designToDelete)
                }
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("Are you sure you want to delete this design? This action cannot be undone.")
        }
        .sheet(isPresented: $showsheet) {
            InfoSheet(design: currentDesign)
                .presentationDetents([.medium, .large])
        }
        .navigationTitle(currentDesign.designName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    let store = DataStore()
    let dummy = Design(
        id: UUID(),
        designName: "Preview Design",
        createdAt: Date(),
        updatedAt: nil,
        isFavorite: false,
        designType: .image,
        designPath: "img1",
        thumbnailPath: "img1",
        albumID: nil
    )

    NavigationStack {
        PreviewView(design: dummy)
            .environment(store)
            .environment(AuthManager())
    }
}
