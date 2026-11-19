import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum PhotoLibraryKind: Sendable { case images, videos, mixed }

nonisolated enum PhotoLibraryMedia: Sendable {
    case image(Data)
    case video(URL)

    func discardTemporaryFile() {
        if case .video(let url) = self { try? FileManager.default.removeItem(at: url) }
    }
}

nonisolated enum PhotoLibraryImportError: Error, LocalizedError {
    case unsupported, imageTooLarge
    var errorDescription: String? {
        switch self {
        case .unsupported: "This photo or video could not be opened. Choose another item."
        case .imageTooLarge: "Choose a photo smaller than 20 MB."
        }
    }
}

nonisolated private final class PhotoLibraryLoad: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PhotoLibraryMedia, Error>?
    private var progress: Progress?
    private var cancelled = false
    private var finished = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func begin(_ continuation: CheckedContinuation<PhotoLibraryMedia, Error>) -> Bool {
        lock.lock()
        if cancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func track(_ progress: Progress) {
        lock.lock()
        let cancel = cancelled
        if !finished && !cancelled { self.progress = progress }
        lock.unlock()
        if cancel { progress.cancel() }
    }

    func complete(_ result: Result<PhotoLibraryMedia, Error>) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            if case .success(let media) = result { media.discardTemporaryFile() }
            return
        }
        finished = true
        let continuation = continuation
        self.continuation = nil
        progress = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    func cancel() {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        cancelled = true
        let progress = progress
        let continuation = continuation
        self.progress = nil
        self.continuation = nil
        if continuation != nil { finished = true }
        lock.unlock()
        progress?.cancel()
        continuation?.resume(throwing: CancellationError())
    }
}

nonisolated enum PhotoLibraryImporter {
    static func load(_ provider: NSItemProvider, kind: PhotoLibraryKind) async throws -> PhotoLibraryMedia {
        let load = PhotoLibraryLoad()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                guard load.begin(continuation) else { return }
                if kind != .images, provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    load.track(provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        guard !load.isCancelled else { return }
                        guard let url else {
                            load.complete(.failure(error ?? PhotoLibraryImportError.unsupported))
                            return
                        }
                        let suffix = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                        let copy = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
                        do {
                            try FileManager.default.copyItem(at: url, to: copy)
                            load.complete(.success(.video(copy)))
                        } catch {
                            try? FileManager.default.removeItem(at: copy)
                            load.complete(.failure(error))
                        }
                    })
                    return
                }
                guard kind != .videos, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                    load.complete(.failure(PhotoLibraryImportError.unsupported))
                    return
                }
                load.track(provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    guard let data, !data.isEmpty else {
                        load.complete(.failure(error ?? PhotoLibraryImportError.unsupported))
                        return
                    }
                    guard data.count <= 20 * 1024 * 1024 else {
                        load.complete(.failure(PhotoLibraryImportError.imageTooLarge))
                        return
                    }
                    load.complete(.success(.image(data)))
                })
            }
        }, onCancel: { load.cancel() })
    }
}

struct PhotoLibraryButton<Label: View>: View {
    let kind: PhotoLibraryKind
    @Binding var isLoading: Bool
    var onStart: () -> Void = {}
    let onPick: (PhotoLibraryMedia) async throws -> Void
    let onError: (Error) -> Void
    @ViewBuilder let label: Label
    @State private var isPresented = false
    @State private var importTask: Task<Void, Never>?
    @State private var requestID: UUID?

    var body: some View {
        Button { isPresented = true } label: { label }
            .disabled(isLoading)
            .sheet(isPresented: $isPresented) {
                PhotoLibraryPicker(kind: kind) { provider in
                    isPresented = false
                    if let provider { receive(provider) }
                }
            }
            .onDisappear {
                importTask?.cancel()
                importTask = nil
                requestID = nil
                isLoading = false
            }
    }

    private func receive(_ provider: NSItemProvider) {
        importTask?.cancel()
        let request = UUID()
        requestID = request
        isLoading = true
        onStart()
        importTask = Task {
            do {
                let media = try await PhotoLibraryImporter.load(provider, kind: kind)
                defer { media.discardTemporaryFile() }
                try Task.checkCancellation()
                try await onPick(media)
            } catch {
                if !Task.isCancelled { onError(error) }
            }
            if requestID == request {
                isLoading = false
                requestID = nil
                importTask = nil
            }
        }
    }
}

private struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let kind: PhotoLibraryKind
    let onSelection: (NSItemProvider?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        switch kind {
        case .images: configuration.filter = .images
        case .videos: configuration.filter = .videos
        case .mixed: configuration.filter = .any(of: [.images, .videos])
        }
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoLibraryPicker
        init(parent: PhotoLibraryPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.onSelection(results.first?.itemProvider)
        }
    }
}
