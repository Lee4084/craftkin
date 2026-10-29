import SwiftUI

struct LearnRootView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        switch coordinator.route {
        case .dashboard:
            LearnDashboardView(coordinator: coordinator)
        case .materials:
            LearningMaterialsView(coordinator: coordinator)
        case .player:
            LearningStepPlayerView(coordinator: coordinator)
        case .questionAnswer:
            LessonQuestionAnswerView(coordinator: coordinator)
        case .practiceSubmission:
            PracticeSubmissionView(coordinator: coordinator)
        case .practiceFeedback:
            PracticeFeedbackView(coordinator: coordinator)
        case .completion:
            LessonCompletionView(coordinator: coordinator)
        case .history:
            LearningHistoryView(coordinator: coordinator)
        }
    }
}

struct LearnHeader: View {
    let title: String
    var backTitle: String? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack {
            if let backTitle, let onBack {
                Button(action: onBack) {
                    Label(backTitle, systemImage: "chevron.left")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Back to \(backTitle)")
            } else {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(EchoTheme.ink)
            }
            Spacer()
            Image(systemName: "bookmark.fill")
                .foregroundStyle(EchoTheme.terracotta)
                .accessibilityHidden(true)
        }
    }
}

struct LearnCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(EchoTheme.line.opacity(0.65), lineWidth: 1)
            }
    }
}

struct LessonProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(EchoTheme.line.opacity(0.7))
                Capsule()
                    .fill(EchoTheme.sage)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(fraction * 100)) percent complete")
    }
}
