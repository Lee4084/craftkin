import PhotosUI
import SwiftUI
import AVFoundation

struct CaptureEntryView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    @State private var pickedVideo: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var importing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CaptureHeader(title: "Capture")
                EchoEyebrow(text: "A voice worth keeping")
                Text("Preserve a family skill.")
                    .font(EchoTheme.title(42))
                    .accessibilityAddTraits(.isHeader)
                Text("Record the little details, original voice and family story—then shape them into a lesson together.")
                    .font(.title3).foregroundStyle(EchoTheme.secondaryInk)

                GeometryReader { geometry in
                    Image("FamilyPottery")
                        .resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .accessibilityLabel("A family member teaching a child pottery")
                }
                    .frame(height: 245)
                    .overlay(alignment: .bottomLeading) {
                        Label("Private until you publish", systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold)).padding(12)
                            .background(.ultraThinMaterial).clipShape(Capsule()).padding(14)
                    }

                Button {
                    if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                        coordinator.startRecording()
                    } else {
                        Task { await openCamera() }
                    }
                } label: {
                    Label("Record Now", systemImage: "video.fill")
                }
                .buttonStyle(EchoPrimaryButtonStyle())

                PhotosPicker(selection: $pickedVideo, matching: .videos) {
                    Label("Import a Video", systemImage: "square.and.arrow.down")
                        .font(.headline).foregroundStyle(EchoTheme.terracotta)
                        .frame(maxWidth: .infinity).frame(minHeight: 54)
                        .background(EchoTheme.paper)
                        .overlay { RoundedRectangle(cornerRadius: 18).stroke(EchoTheme.terracotta, lineWidth: 1.4) }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityLabel("Import a Video")
                .onChange(of: pickedVideo) { _, selection in
                    guard let selection else { return }
                    Task {
                        importing = true
                        defer { importing = false; pickedVideo = nil }
                        do {
                            guard let movie = try await selection.loadTransferable(type: ImportedVideo.self) else { throw LocalMediaError.unsupportedType }
                            defer { try? FileManager.default.removeItem(at: movie.url) }
                            await retainVideo(movie.url)
                        } catch { coordinator.validationMessage = error.localizedDescription }
                    }
                }
                .disabled(importing)
                if importing { ProgressView("Saving your video…") }
                #if targetEnvironment(simulator)
                Button("Try with Example Content") { coordinator.importSampleVideo() }
                    .font(.subheadline).frame(minHeight: 44)
                #endif

                if coordinator.hasSavedDraft {
                    CaptureCard {
                        HStack {
                            CaptureStatusPill(text: draftStatus, icon: "doc.text.magnifyingglass")
                            Spacer()
                            Text(coordinator.draft.sourceDuration.echoTimestamp).font(.caption.monospacedDigit())
                        }
                        Text(coordinator.draft.title.isEmpty ? "Untitled family skill" : coordinator.draft.title)
                            .font(.system(.title3, design: .serif, weight: .bold))
                        Text("Your latest private draft is safely stored on this device.")
                            .foregroundStyle(EchoTheme.secondaryInk)
                        Button("Continue Draft") { coordinator.continueDraft() }
                            .buttonStyle(EchoSecondaryButtonStyle())
                    }
                }

                CaptureCard {
                    Label("A better recording", systemImage: "lightbulb.fill").font(.headline).foregroundStyle(EchoTheme.terracotta)
                    Text("Keep hands in frame, reduce background noise, and ask the maker to explain why each detail matters.")
                        .font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
                    Text("Launch V1 supports videos up to 10 minutes.").font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(isPresented: $showsCamera) {
            CameraVideoPicker(maximumDuration: 600, onVideo: { url in
                showsCamera = false
                Task { await retainVideo(url) }
            }, onCancel: { showsCamera = false }).ignoresSafeArea()
        }
    }

    private func retainVideo(_ url: URL) async {
        do {
            let imported = try await LocalVideoImporter.retain(url, maximumDuration: 600)
            coordinator.importSource(filename: imported.filename, duration: imported.duration)
        } catch { coordinator.validationMessage = error.localizedDescription }
    }

    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            coordinator.validationMessage = "This device has no available camera. Import a video instead."
            return
        }
        let camera = await AVCaptureDevice.requestAccess(for: .video)
        guard camera else { coordinator.validationMessage = "Allow Camera access in iOS Settings, or import a video."; return }
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphone else { coordinator.validationMessage = "Allow Microphone access in iOS Settings to record the maker’s voice, or import a video."; return }
        showsCamera = true
    }

    private var draftStatus: String {
        switch coordinator.draft.lifecycle {
        case .needsAttention: return "Needs attention"
        case .needsReview, .readyToPublish: return "Ready to review"
        case .processing, .uploading: return "Processing"
        case .published: return "Published"
        default: return "Saved draft"
        }
    }
}

struct VideoRecordingView: View {
    @ObservedObject var coordinator: CaptureCoordinator

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("FamilyRepair")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                LinearGradient(colors: [.black.opacity(0.68), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)

                VStack(spacing: 18) {
                    HStack {
                        Button("Close") { coordinator.goBack() }.foregroundStyle(.white).font(.headline).frame(minHeight: 44)
                        Spacer()
                        Text(coordinator.recordingSeconds.echoTimestamp)
                            .font(.headline.monospacedDigit()).foregroundStyle(.white).padding(.horizontal, 14).frame(minHeight: 38)
                            .background(.black.opacity(0.45)).clipShape(Capsule())
                    }

                    Spacer()
                    Text("Framing example · not a live camera feed")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    CaptureStatusPill(text: "Keep hands and tools in frame", icon: "hand.raised.fill", color: .white)
                        .background(.black.opacity(0.25)).clipShape(Capsule())
                    Text("Clear, close audio helps your family review the original voice later.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: geometry.size.width - 40)

                    HStack(spacing: 34) {
                        Button { coordinator.toggleRecording() } label: {
                            Image(systemName: coordinator.isRecording ? "pause.fill" : "record.circle")
                                .font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 62, height: 62).background(.black.opacity(0.42)).clipShape(Circle())
                        }
                        .accessibilityLabel(coordinator.isRecording ? "Pause Recording" : "Start Recording")

                        Button {
                            coordinator.finishRecording()
                        } label: {
                            Circle().fill(EchoTheme.terracotta).frame(width: 82, height: 82)
                                .overlay { RoundedRectangle(cornerRadius: 7).fill(.white).frame(width: 27, height: 27) }
                        }
                        .accessibilityLabel("Stop Recording")

                        Button { } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 25)).foregroundStyle(.white)
                                .frame(width: 62, height: 62).background(.black.opacity(0.42)).clipShape(Circle())
                        }
                        .accessibilityLabel("Switch Camera")
                    }
                    Text("10:00 maximum · segments are saved locally")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: geometry.size.width - 40)
                }
                .frame(width: max(geometry.size.width - 40, 0))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .clipped()
        }
    }
}

struct LessonDetailsView: View {
    @ObservedObject var coordinator: CaptureCoordinator

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Lesson Details")
            if let filename = coordinator.draft.sourceMediaFilename { SourceVideoView(filename: filename) }
            EchoEyebrow(text: "Private draft")
            Text("Tell us what this skill means.").font(EchoTheme.title(37)).accessibilityAddTraits(.isHeader)
            Text("These details help family members find and understand the lesson. You can edit them later.")
                .foregroundStyle(EchoTheme.secondaryInk)

            HStack(spacing: 14) {
                if coordinator.draft.sourceMediaFilename == nil {
                    Image(RuntimePhotos.cover(coordinator.draft.selectedCover, title: coordinator.draft.title))
                        .resizable().scaledToFill().frame(width: 118, height: 82).clipped().clipShape(RoundedRectangle(cornerRadius: 15))
                        .accessibilityLabel("Illustrative draft cover, not a source video frame")
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Source video saved").font(.headline)
                    Text(coordinator.draft.sourceDuration.echoTimestamp).font(.subheadline.monospacedDigit()).foregroundStyle(EchoTheme.secondaryInk)
                    CaptureStatusPill(text: "Private", icon: "lock.fill")
                }
            }

            detailsField("Skill title", text: $coordinator.draft.title, prompt: "Grandma's dumplings")
            detailsField("Maker", text: $coordinator.draft.maker, prompt: "Who is teaching?")
            detailsField("Spoken language", text: $coordinator.draft.language, prompt: "English, Spanish…")
            detailsField("Category (optional)", text: $coordinator.draft.category, prompt: "Recipes, repairs, crafts…")

            Text("Family story (optional)").font(.subheadline.weight(.semibold))
            TextEditor(text: $coordinator.draft.familyStory)
                .frame(minHeight: 92).padding(10).background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 15)).overlay { RoundedRectangle(cornerRadius: 15).stroke(EchoTheme.line) }
                .accessibilityLabel("Family story")
            Toggle("Keep original voice", isOn: $coordinator.draft.keepOriginalVoice).font(.headline).tint(EchoTheme.terracotta)

            Button("Create Lesson Draft") { coordinator.createLessonDraft() }
                .buttonStyle(EchoPrimaryButtonStyle())
            Button("Save Draft") { coordinator.saveDraft() }
                .buttonStyle(EchoSecondaryButtonStyle())
        }
    }

    private func detailsField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(prompt, text: text).textFieldStyle(.plain).padding(14).background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 15)).overlay { RoundedRectangle(cornerRadius: 15).stroke(EchoTheme.line) }
                .accessibilityLabel(title)
        }
    }
}

struct DraftProcessingView: View {
    @ObservedObject var coordinator: CaptureCoordinator

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Creating Draft")
            GeometryReader { geometry in
                Image("FamilyPaperCraft").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("Paper craft inspiration, not a frame from your recording")
            }.frame(height: 190)
            EchoEyebrow(text: "Local processing")
            Text("Turning a recording into a lesson.").font(EchoTheme.title(36)).accessibilityAddTraits(.isHeader)
            Text(coordinator.draft.sourceMediaFilename == nil
                 ? "Review this example draft to explore the complete lesson workflow."
                 : "Your video is saved. Add the maker’s words, materials and steps in the next screens. Automatic transcription is not connected in this build.")
                .foregroundStyle(EchoTheme.secondaryInk)

            ForEach(DraftProcessingStage.allCases, id: \.self) { stage in
                HStack(spacing: 12) {
                    Image(systemName: stage == coordinator.draft.processingStage ? "circle.dotted" : "checkmark.circle.fill")
                        .foregroundStyle(stage == coordinator.draft.processingStage ? EchoTheme.terracotta : EchoTheme.sage)
                    VStack(alignment: .leading) {
                        Text(stage.title).font(.headline)
                        Text(stage.subtitle).font(.caption).foregroundStyle(EchoTheme.secondaryInk)
                    }
                    Spacer()
                }
                .padding(13).background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 15))
            }

            Button("Review Draft") { coordinator.completeLocalProcessing() }
                .buttonStyle(EchoPrimaryButtonStyle())
            Button("Continue in Background") { coordinator.returnToEntry() }
                .buttonStyle(EchoSecondaryButtonStyle())
            Button("Show Recovery Options") { coordinator.failTranscriptProcessing() }
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

private extension DraftProcessingStage {
    var title: String {
        switch self {
        case .source: return "Source saved"
        case .transcript: return "Transcript"
        case .steps: return "Step proposal"
        case .keyframes: return "Key moments"
        case .reviewPackage: return "Review package"
        }
    }

    var subtitle: String {
        switch self {
        case .source: return "Private video is retained"
        case .transcript: return "Original words stay time-linked"
        case .steps: return "Editable lesson structure"
        case .keyframes: return "Frames come from the source"
        case .reviewPackage: return "Ready for your approval"
        }
    }
}
