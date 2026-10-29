import AVFoundation
import CoreVideo
import Foundation
import Testing
@testable import Craftkin

@MainActor
struct VideoImportTests {
    @Test("A real video is retained, reviewed, published and opened by Learn")
    func realVideoLifecycle() async throws {
        let source = try await makeVideo()
        defer { try? FileManager.default.removeItem(at: source) }
        let imported = try await LocalVideoImporter.retain(source, maximumDuration: 600)
        defer { try? LocalMediaStore().delete(imported.filename) }
        #expect(LocalMediaStore().url(for: imported.filename) != nil)
        #expect(imported.duration > 0 && imported.duration <= 3)
        let capture = CaptureCoordinator(store: InMemoryCaptureDraftStore())
        capture.importSource(filename: imported.filename, duration: imported.duration)
        capture.draft.title = "Fold a paper bookmark"
        capture.draft.maker = "Alex"
        capture.draft.language = "English"
        #expect(capture.createLessonDraft())
        capture.completeLocalProcessing()
        capture.draft.transcript[0].text = "Fold the top corner down carefully."
        capture.draft.steps[0].instruction = "Fold the top corner down."
        capture.approveTranscript()
        capture.approveMaterials()
        #expect(capture.approveSteps())
        capture.publish()
        #expect(capture.route == .success)
        let lesson = IntegratedLessonFactory.learningLesson(from: capture.draft)
        #expect(lesson.sourceMediaFilename == imported.filename)
        let url = try #require(LocalMediaStore().url(for: lesson.sourceMediaFilename))
        let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
        #expect(!tracks.isEmpty)
        let learner = LearnCoordinator(lesson: lesson, store: InMemoryLearningProgressStore())
        learner.beginSteps()
        learner.markCurrentStepComplete()
        learner.skipPractice()
        #expect(learner.progress.lifecycle == .completed)
    }

    @Test("Video duration is enforced before a file enters owned media storage")
    func videoDurationLimit() async throws {
        let source = try await makeVideo()
        defer { try? FileManager.default.removeItem(at: source) }
        do {
            _ = try await LocalVideoImporter.retain(source, maximumDuration: 0.1)
            Issue.record("A longer video was accepted")
        } catch let error as LocalMediaError { #expect(error.localizedDescription == LocalMediaError.invalidDuration.localizedDescription) }
    }

    private func makeVideo() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                                        AVVideoWidthKey: 64, AVVideoHeightKey: 64])
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                                        kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for index in 0..<10 {
            var attempts = 0
            while !input.isReadyForMoreMediaData {
                attempts += 1
                guard attempts < 2000, writer.status == .writing else { throw LocalMediaError.unsupportedType }
                try await Task.sleep(for: .milliseconds(5))
            }
            var pixel: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixel)
            let buffer = try #require(pixel)
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), 100, CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            #expect(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 5)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
}
