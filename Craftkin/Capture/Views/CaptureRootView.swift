import SwiftUI

struct CaptureRootView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    let onGoToLibrary: () -> Void
    var onViewLesson: (() -> Void)? = nil

    var body: some View {
        ZStack {
            EchoTheme.ivory.ignoresSafeArea()
            currentScreen
        }
        .alert(
            "Check this draft",
            isPresented: Binding(
                get: { coordinator.validationMessage != nil },
                set: { if !$0 { coordinator.validationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { coordinator.validationMessage = nil }
        } message: {
            Text(coordinator.validationMessage ?? "")
        }
        .tint(EchoTheme.terracotta)
        .sheet(isPresented: $coordinator.showsPreview) { CaptureLessonPreview(draft: coordinator.draft) }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch coordinator.route {
        case .entry:
            CaptureEntryView(coordinator: coordinator)
        case .recording:
            VideoRecordingView(coordinator: coordinator)
        case .details:
            LessonDetailsView(coordinator: coordinator)
        case .processing:
            DraftProcessingView(coordinator: coordinator)
        case .transcript:
            TranscriptReviewView(coordinator: coordinator)
        case .materials:
            MaterialsReviewView(coordinator: coordinator)
        case .steps:
            StepsEditorView(coordinator: coordinator)
        case .sharing:
            CoverSharingView(coordinator: coordinator)
        case .success:
            PublishSuccessView(
                coordinator: coordinator,
                onViewLesson: onViewLesson ?? onGoToLibrary,
                onGoToLibrary: onGoToLibrary
            )
        case .recovery:
            ProcessingRecoveryView(coordinator: coordinator)
        }
    }
}

private struct CaptureLessonPreview: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var learner: LearnCoordinator
    init(draft: CaptureDraft) {
        _learner = StateObject(wrappedValue: LearnCoordinator(lesson: IntegratedLessonFactory.learningLesson(from: draft),
                                                            store: InMemoryLearningProgressStore()))
    }
    var body: some View {
        NavigationStack {
            LearnRootView(coordinator: learner)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .navigationTitle("Lesson Preview").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CaptureHeader: View {
    let title: String
    var backTitle: String? = nil
    var onBack: () -> Void = {}

    var body: some View {
        HStack {
            if let backTitle {
                LibraryBackButton(title: backTitle, action: onBack)
            } else {
                Text("EchoSkill").font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(EchoTheme.terracotta)
            }
            Spacer()
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.secondaryInk)
        }
        .frame(minHeight: 44)
    }
}

struct CaptureStatusPill: View {
    let text: String
    let icon: String
    var color = EchoTheme.sage

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct CaptureCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(EchoTheme.line.opacity(0.6)) }
    }
}

extension TimeInterval {
    var echoTimestamp: String {
        let seconds = max(Int(self), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
