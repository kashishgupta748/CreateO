import SwiftUI
import AVFoundation
import AVKit

struct DesignCard: View {
    let size: CGSize
    let design: Design

    @Environment(DataStore.self) private var designStore

    @State private var showDeleteAlert = false
    @State private var showRenameSheet = false
    @State private var renameDraft = ""
    @State private var videoDurationText: String?

    private var currentDesign: Design {
        designStore.designs.first(where: { $0.id == design.id }) ?? design
    }

    private var shareURL: URL {
        URL(fileURLWithPath: currentDesign.designPath)
    }

    private var cardAspectRatio: CGFloat {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        return width / height
    }

    var body: some View {
        NavigationLink {
            destinationView
        } label: {
            ZStack(alignment: .bottomTrailing) {
                DesignImageView(path: currentDesign.thumbnailPath)
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    }

                if currentDesign.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                      .padding(12)
                        .frame(width: size.width, height: size.height, alignment: .topTrailing)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    HStack(spacing: 12) {
                        Text(currentDesign.designName.isEmpty ? "Untitled Design" : currentDesign.designName)
                            .font(.system(size: currentDesign.designType == .video ? 18 : 13,
                                          weight: currentDesign.designType == .video ? .bold : .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer()

                        if currentDesign.designType == .video, let videoDurationText {
                            Text(videoDurationText)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, currentDesign.designType == .video ? 14 : 11)
                    .padding(.top, currentDesign.designType == .video ? 56 : 30)
                }
                .frame(width: size.width, height: size.height)
                .background(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(currentDesign.designType == .video ? 0.72 : 0.58)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .task(id: currentDesign.id) {
            await loadVideoDuration()
        }
        .contextMenu {
            Button {
                renameDraft = currentDesign.designName
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                toggleFavourite()
            } label: {
                Label(
                    currentDesign.isFavorite ? "Remove Favourite" : "Favourite",
                    systemImage: currentDesign.isFavorite ? "heart.slash" : "heart"
                )
            }

            ShareLink(item: shareURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Design?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                designStore.deleteDesign(design: currentDesign)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this design? This action cannot be undone.")
        }
        .sheet(isPresented: $showRenameSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Design name", text: $renameDraft)
                    }

                    Section {
                        Button("Save") {
                            let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }

                            designStore.renameDesign(id: currentDesign.id, newName: trimmed)
                            showRenameSheet = false
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .navigationTitle("Rename")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showRenameSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        if currentDesign.designType == .video {
            StoryVideoPreviewView(design: currentDesign)
        } else {
            PreviewView(design: currentDesign)
        }
    }

    private func loadVideoDuration() async {
        guard currentDesign.designType == .video else {
            await MainActor.run {
                videoDurationText = nil
            }
            return
        }

        let url = URL(fileURLWithPath: currentDesign.designPath)
        let asset = AVURLAsset(url: url)

        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)

            guard seconds.isFinite, seconds > 0 else {
                await MainActor.run {
                    videoDurationText = nil
                }
                return
            }

            let wholeSeconds = Int(seconds.rounded(.up))

            await MainActor.run {
                videoDurationText = String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
            }
        } catch {
            await MainActor.run {
                videoDurationText = nil
            }
        }
    }

    private func toggleFavourite() {
        if currentDesign.isFavorite {
            designStore.removeFavourite(currentDesign)
        } else {
            var updated = currentDesign
            updated.isFavorite = true
            updated.updatedAt = Date()
            designStore.updateDesign(design: updated)
        }
    }
}

private struct StoryVideoPreviewView: View {
    let design: Design

    @Environment(DataStore.self) private var designStore
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: Double = 0
    @State private var playbackObserverToken: Any?
    @State private var endObserverToken: NSObjectProtocol?

    @State private var showDeleteAlert = false
    @State private var showInfoSheet = false
    @State private var showStoryEditor = false

    private var currentDesign: Design {
        designStore.designs.first(where: { $0.id == design.id }) ?? design
    }

    private var storyDraft: StoryBoardDraft? {
        guard let projectPath = currentDesign.projectPath,
              !projectPath.isEmpty,
              let data = FileManager.default.contents(atPath: projectPath),
              let snapshot = try? JSONDecoder().decode(SavedStoryProjectSnapshot.self, from: data) else {
            return nil
        }

        let transitions = snapshot.gapTransitions.compactMapValues {
            StoryTransition(rawValue: $0)
        }

        return StoryBoardDraft(
            storyName: snapshot.storyName,
            pageDesignIDs: snapshot.pageDesignIDs,
            gapTransitions: transitions
        )
    }

    private var storyPages: [Design] {
        guard let storyDraft else { return [] }

        let lookup = Dictionary(uniqueKeysWithValues: designStore.designs.map { ($0.id, $0) })
        return storyDraft.pageDesignIDs.compactMap { lookup[$0] }
    }

    private var shareURL: URL {
        URL(fileURLWithPath: currentDesign.designPath)
    }

    private var videoAspectRatio: CGFloat {
        let width = max(CGFloat(currentDesign.designWidth), 1)
        let height = max(CGFloat(currentDesign.designHeight), 1)
        return width / height
    }

    private var durationText: String {
        guard playbackDuration.isFinite, playbackDuration > 0 else {
            return "0:00"
        }

        let wholeSeconds = Int(playbackDuration.rounded(.up))
        return String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 24
            let verticalPadding: CGFloat = 126
            let maxWidth = max(geo.size.width - horizontalPadding, 220)
            let maxHeight = max(geo.size.height - verticalPadding, 320)
            let mediaWidth = min(maxWidth, maxHeight * videoAspectRatio)
            let mediaHeight = mediaWidth / max(videoAspectRatio, 0.01)

            VStack(spacing: 18) {
                Spacer(minLength: 16)

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                    if player != nil {
                        StoryVideoSurfaceView(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: mediaWidth, height: mediaHeight)

                playbackControls
                    .frame(width: min(mediaWidth, geo.size.width - 48))

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(currentDesign.designName.isEmpty ? "Story" : currentDesign.designName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showStoryEditor = true
                }
                .disabled(storyDraft == nil)
            }

            ToolbarItemGroup(placement: .bottomBar) {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Spacer()

                Button {
                    designStore.toggleFavorite(id: currentDesign.id)
                } label: {
                    Image(systemName: currentDesign.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(currentDesign.isFavorite ? .red : .primary)
                }

                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }

                Spacer()

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onAppear {
            configurePlayerIfNeeded()
        }
        .onDisappear {
            teardownPlayer()
        }
        .sheet(isPresented: $showInfoSheet) {
            storyInfoSheet
        }
        .navigationDestination(isPresented: $showStoryEditor) {
            if let storyDraft {
                StoryBoard(initialDraft: storyDraft)
            }
        }
        .alert("Delete Story?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                designStore.deleteDesign(design: currentDesign)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the saved story video from your designs.")
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { playbackProgress },
                    set: { playbackProgress = $0 }
                ),
                in: 0...max(playbackDuration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        seekToProgress(playbackProgress)
                    }
                }
            )
            .tint(Color.primary.opacity(0.72))

            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 38)
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
    }

    private var storyInfoSheet: some View {
        NavigationStack {
            List {
                Section("Story") {
                    infoRow(title: "Name", value: currentDesign.designName)
                    infoRow(title: "Duration", value: durationText)
                    infoRow(title: "Pages", value: "\(storyPages.count)")
                }

                Section("Saved") {
                    infoRow(title: "Created", value: storyDateText(currentDesign.createdAt))
                    infoRow(title: "Updated", value: storyDateText(currentDesign.updatedAt ?? currentDesign.createdAt))
                }
            }
            .navigationTitle("Story Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showInfoSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func configurePlayerIfNeeded() {
        guard player == nil else { return }

        let url = URL(fileURLWithPath: currentDesign.designPath)
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)

        avPlayer.pause()
        player = avPlayer

        Task {
            do {
                let duration = try await item.asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)

                guard seconds.isFinite, seconds > 0 else { return }

                await MainActor.run {
                    playbackDuration = seconds
                }
            } catch { }
        }

        playbackObserverToken = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)

            if seconds.isFinite {
                playbackProgress = seconds
            }
        }

        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            isPlaying = false
            playbackProgress = playbackDuration
            avPlayer.pause()
        }
    }

    private func teardownPlayer() {
        if let playbackObserverToken {
            player?.removeTimeObserver(playbackObserverToken)
            self.playbackObserverToken = nil
        }

        if let endObserverToken {
            NotificationCenter.default.removeObserver(endObserverToken)
            self.endObserverToken = nil
        }

        player?.pause()
        player = nil
        isPlaying = false
    }

    private func togglePlayback() {
        configurePlayerIfNeeded()
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        if playbackDuration > 0, playbackProgress >= playbackDuration - 0.05 {
            seekToProgress(0)
        }

        player.play()
        isPlaying = true
    }

    private func seekToProgress(_ value: Double) {
        configurePlayerIfNeeded()

        let safeValue = min(max(value, 0), max(playbackDuration, 0))
        playbackProgress = safeValue

        let targetTime = CMTime(seconds: safeValue, preferredTimescale: 600)
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func storyDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct SavedStoryProjectSnapshot: Codable {
    let storyName: String
    let pageDesignIDs: [UUID]
    let gapTransitions: [Int: String]
    let duration: Double
    let createdAt: Date
}

private struct StoryVideoSurfaceView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> StoryVideoPlayerView {
        let view = StoryVideoPlayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: StoryVideoPlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class StoryVideoPlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
