import SwiftUI

struct LearningStepPlayerView: View {
    @ObservedObject var coordinator: LearnCoordinator
    @State private var isPlaying = false

    var body: some View {
        EchoScreen {
            LearnHeader(title: "Lesson", backTitle: "Materials", onBack: coordinator.startLesson)
            HStack {
                EchoEyebrow(text: "Step \(coordinator.clampedStepIndex + 1) of \(coordinator.lesson.steps.count)")
                Spacer()
                Text("\(coordinator.progress.completedStepIDs.count) completed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EchoTheme.sage)
            }
            LessonProgressBar(fraction: coordinator.completedFraction)

            if let filename = coordinator.lesson.sourceMediaFilename {
                SourceVideoView(filename: filename, start: coordinator.currentStep.start, end: coordinator.currentStep.end,
                                seekPosition: coordinator.progress.playbackPosition, seekToken: coordinator.playbackSeekToken,
                                onCheckpoint: coordinator.checkpointPlayback)
            } else { ZStack {
                GeometryReader { geometry in
                    Image(coordinator.lesson.imageName).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }.frame(height: 250)
                Color.black.opacity(0.25)
                Button { isPlaying.toggle() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .accessibilityLabel(isPlaying ? "Pause lesson video" : "Play lesson video")
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            HStack {
                Button { coordinator.previousStep() } label: {
                    Label("Previous", systemImage: "backward.end.fill")
                }
                .disabled(coordinator.clampedStepIndex == 0)
                Spacer()
                Button { coordinator.replayLastSeconds() } label: {
                    Label("Replay 5s", systemImage: "gobackward.5")
                }
                Spacer()
                Button { coordinator.nextStep() } label: {
                    Label("Next", systemImage: "forward.end.fill")
                }
                .disabled(coordinator.clampedStepIndex == coordinator.lesson.steps.count - 1)
            }
            .font(.caption.weight(.semibold))

            LearnCard {
                Text(coordinator.currentStep.title)
                    .font(EchoTheme.title(30))
                Text(coordinator.currentStep.instruction)
                    .foregroundStyle(EchoTheme.secondaryInk)
                if let tip = coordinator.currentStep.familyTip {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "quote.bubble.fill").foregroundStyle(EchoTheme.terracotta)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(coordinator.lesson.makerRelation)’s detail").font(.caption.weight(.bold))
                            Text(tip).font(.subheadline)
                        }
                    }
                    .padding(12)
                    .background(EchoTheme.terracottaSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }

            Button("Mark Step Complete", action: coordinator.markCurrentStepComplete)
                .buttonStyle(EchoPrimaryButtonStyle())
            Button("Ask About This Step", action: coordinator.askQuestion)
                .buttonStyle(EchoSecondaryButtonStyle())
                .disabled(coordinator.lesson.allowsQuestions == false)
        }
        .onDisappear { isPlaying = false }
    }
}

struct LessonQuestionAnswerView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            LearnHeader(title: "Questions", backTitle: "Step", onBack: coordinator.returnToPlayer)
            EchoEyebrow(text: "Grounded in this lesson")
            Text("Ask from the family lesson.")
                .font(EchoTheme.title(38))
            Text("Answers use only the notes and instructions your family approved. They do not search the web.")
                .foregroundStyle(EchoTheme.secondaryInk)

            Button("Why leave gaps in the lattice?") {
                coordinator.questionText = "Why leave gaps in the lattice?"
                coordinator.submitQuestion()
            }
            .buttonStyle(EchoSecondaryButtonStyle())

            ForEach(coordinator.answers) { answer in
                LearnCard {
                    Text(answer.question).font(.caption.weight(.bold)).foregroundStyle(EchoTheme.secondaryInk)
                    Text(answer.text).font(.body.weight(.semibold))
                    ForEach(answer.sources, id: \.self) { source in
                        Label(source, systemImage: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(EchoTheme.terracotta)
                    }
                }
            }

            LearnCard {
                TextField("Ask about a step or family tip", text: $coordinator.questionText, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityLabel("Lesson question")
                Button("Ask Lesson", action: coordinator.submitQuestion)
                    .buttonStyle(EchoPrimaryButtonStyle())
                    .disabled(coordinator.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct PracticeSubmissionView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            LearnHeader(title: "Practice", backTitle: "Lesson", onBack: coordinator.returnToPlayer)
            EchoEyebrow(text: "Optional practice")
            Text("Show what you learned.")
                .font(EchoTheme.title(39))
            Text("Add one photo or a video up to 60 seconds. It stays private until you decide to share.")
                .foregroundStyle(EchoTheme.secondaryInk)

            LearnCard {
                if coordinator.practice.mediaKind != nil {
                    PracticeMediaPreview(practice: coordinator.practice)
                    Label(coordinator.practice.mediaKind == .photo ? "Photo ready" : "\(Int(coordinator.practice.mediaDuration ?? 0))-second video ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(EchoTheme.sage)
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 46))
                        .foregroundStyle(EchoTheme.terracotta)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                PracticeMediaPicker(coordinator: coordinator)
                if ProcessInfo.processInfo.arguments.contains("-uiTesting") { HStack {
                    Button("Use Sample Photo", action: coordinator.choosePracticePhoto)
                    Spacer()
                    Button("Use Sample Video") { coordinator.choosePracticeVideo() }
                }
                .font(.subheadline.weight(.semibold))
                }
            }

            TextField("Add a note about your practice (optional)", text: $coordinator.practice.note, axis: .vertical)
                .lineLimit(3...6)
                .padding(15)
                .background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Practice note")
            Text("\(coordinator.practice.note.count)/500")
                .font(.caption)
                .foregroundStyle(coordinator.practice.note.count > 500 ? .red : EchoTheme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Label("Private by default", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EchoTheme.sage)
            if let message = coordinator.validationMessage {
                Text(message).font(.footnote.weight(.semibold)).foregroundStyle(.red)
            }
            Button("Submit Practice") { coordinator.submitPractice() }
                .buttonStyle(EchoPrimaryButtonStyle())
            Button("Skip for Now", action: coordinator.skipPractice)
                .buttonStyle(EchoSecondaryButtonStyle())
        }
    }
}

struct PracticeFeedbackView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            LearnHeader(title: "Practice", backTitle: "Edit", onBack: { coordinator.route = .practiceSubmission })
            EchoEyebrow(text: "Saved on this device")
            Text("A private first try.")
                .font(EchoTheme.title(39))
            Text(coordinator.progress.practice.isSharedWithFamily ? "Shared with your family." : "Only you can see this practice.")
                .font(.headline)
                .foregroundStyle(coordinator.progress.practice.isSharedWithFamily ? EchoTheme.terracotta : EchoTheme.sage)

            PracticeMediaPreview(practice: coordinator.progress.practice)

            LearnCard {
                Text("Your note").font(.caption.weight(.bold)).foregroundStyle(EchoTheme.secondaryInk)
                Text(coordinator.progress.practice.note.isEmpty ? "No note added." : coordinator.progress.practice.note)
                Divider()
                Label("Family comments appear only after you share", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }

            if !coordinator.progress.practice.isSharedWithFamily {
                Button("Share with Family", action: coordinator.sharePracticeWithFamily)
                    .buttonStyle(EchoSecondaryButtonStyle())
            }
            if coordinator.canFinish {
                Button("Finish Lesson", action: coordinator.finishLesson).buttonStyle(EchoPrimaryButtonStyle())
            } else {
                Button("Back to Learn", action: coordinator.showDashboard).buttonStyle(EchoPrimaryButtonStyle())
            }
        }
    }
}

struct LessonCompletionView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            Spacer(minLength: 20)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 86))
                .foregroundStyle(EchoTheme.sage)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            EchoEyebrow(text: "Lesson complete")
                .frame(maxWidth: .infinity)
            Text("You carried it forward.")
                .font(EchoTheme.title(42))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("You completed all \(coordinator.lesson.steps.count) steps in \(coordinator.lesson.title). Your progress is safely saved on this device.")
                .foregroundStyle(EchoTheme.secondaryInk)
                .multilineTextAlignment(.center)

            LearnCard {
                HStack {
                    completionMetric(value: "\(coordinator.lesson.steps.count)", label: "Steps")
                    Spacer()
                    completionMetric(value: "\(coordinator.lesson.durationMinutes)", label: "Minutes")
                    Spacer()
                    completionMetric(value: "\(coordinator.progress.passNumber)", label: "Pass")
                }
            }

            Button("View Learning History", action: coordinator.showHistory)
                .buttonStyle(EchoPrimaryButtonStyle())
            Button("Learn Again", action: coordinator.learnAgain)
                .buttonStyle(EchoSecondaryButtonStyle())
            Button("Back to Learn", action: coordinator.showDashboard)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func completionMetric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(EchoTheme.title(30)).foregroundStyle(EchoTheme.terracotta)
            Text(label).font(.caption).foregroundStyle(EchoTheme.secondaryInk)
        }
    }
}
