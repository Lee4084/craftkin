import AVKit
import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct ImportedVideo: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ImportedVideo(url: copy)
        }
    }
}

struct SourceVideoView: View {
    let filename: String
    var start: TimeInterval = 0
    var end: TimeInterval? = nil
    var seekPosition: TimeInterval = 0
    var seekToken = 0
    var onCheckpoint: (TimeInterval) -> Void = { _ in }
    @State private var player: AVPlayer?
    @State private var observer: Any?

    var body: some View {
        Group {
            if let player { VideoPlayer(player: player).accessibilityIdentifier("Source Video Player") }
            else { ContentUnavailableView("Video unavailable", systemImage: "video.slash", description: Text("The local source file could not be opened.")) }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear { configure() }
        .onChange(of: seekToken) { _, _ in seek() }
        .onChange(of: start) { _, _ in seek() }
        .onDisappear {
            if let player {
                let current = player.currentTime().seconds
                if current.isFinite { onCheckpoint(current) }
                player.pause()
                if let observer { player.removeTimeObserver(observer) }
            }
            observer = nil
            player = nil
        }
    }

    private func configure() {
        guard player == nil, let url = LocalMediaStore().url(for: filename) else { return }
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        seek()
        observer = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { time in
            Task { @MainActor in
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                if let end, seconds >= end { newPlayer.pause() }
                onCheckpoint(min(seconds, end ?? seconds))
            }
        }
    }

    private func seek() {
        player?.seek(to: CMTime(seconds: max(start, seekPosition), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

struct CameraVideoPicker: UIViewControllerRepresentable {
    let maximumDuration: TimeInterval
    let onVideo: (URL) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoMaximumDuration = maximumDuration
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraVideoPicker
        init(parent: CameraVideoPicker) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let url = info[.mediaURL] as? URL else { parent.onCancel(); return }
            parent.onVideo(url)
        }
    }
}

enum LocalVideoImporter {
    static func retain(_ url: URL, maximumDuration: TimeInterval) async throws -> (filename: String, duration: TimeInterval) {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty, duration.isFinite, duration > 0, duration <= maximumDuration else { throw LocalMediaError.invalidDuration }
        return (try LocalMediaStore().importFile(url), duration)
    }
}

struct PracticeMediaPicker: View {
    @ObservedObject var coordinator: LearnCoordinator
    @State private var selection: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .any(of: [.images, .videos])) {
            Label(isImporting ? "Importing…" : "Choose a Photo or Video", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(EchoSecondaryButtonStyle())
        .disabled(isImporting)
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                isImporting = true
                defer { isImporting = false; selection = nil }
                do {
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        guard let movie = try await item.loadTransferable(type: ImportedVideo.self) else { throw LocalMediaError.unsupportedType }
                        defer { try? FileManager.default.removeItem(at: movie.url) }
                        let imported = try await LocalVideoImporter.retain(movie.url, maximumDuration: 60)
                        coordinator.choosePracticeVideo(duration: imported.duration)
                        coordinator.practice.mediaFilename = imported.filename
                    } else {
                        guard let data = try await item.loadTransferable(type: Data.self), data.count <= 20 * 1024 * 1024,
                              let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8) else { throw LocalMediaError.unsupportedType }
                        let filename = try LocalMediaStore().save(jpeg, extension: "jpg")
                        coordinator.choosePracticePhoto()
                        coordinator.practice.mediaFilename = filename
                    }
                } catch { coordinator.validationMessage = error.localizedDescription }
            }
        }
    }
}

struct PracticeMediaPreview: View {
    let practice: PracticeSubmission
    var body: some View {
        if let filename = practice.mediaFilename, let url = LocalMediaStore().url(for: filename) {
            if practice.mediaKind == .video { SourceVideoView(filename: filename) }
            else if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityLabel("Your practice photo")
            }
        } else {
            GeometryReader { geometry in
                Image("FamilyPaperCraft").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("Illustrative paper craft photograph")
            }.frame(height: 200)
            Text("Illustrative photo — not an uploaded practice.")
                .font(.caption).foregroundStyle(EchoTheme.secondaryInk)
        }
    }
}
