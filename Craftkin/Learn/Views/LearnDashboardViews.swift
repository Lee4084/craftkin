import SwiftUI

struct LearnDashboardView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            LearnHeader(title: "Learn")

            VStack(alignment: .leading, spacing: 5) {
                EchoEyebrow(text: "Your family classroom")
                Text("Continue learning, together.")
                    .font(EchoTheme.title(39))
                    .foregroundStyle(EchoTheme.ink)
                Text("Practice a skill at your pace, with the details your family chose to preserve.")
                    .font(.body)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }

            LearnCard {
                GeometryReader { geometry in
                    Image(coordinator.lesson.imageName)
                        .resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .accessibilityLabel("Cover for \(coordinator.lesson.title)")
                }.frame(height: 190)

                HStack {
                    Text(coordinator.progress.lifecycle == .ready ? "READY TO LEARN" : (coordinator.progress.lifecycle == .completed ? "COMPLETED" : "IN PROGRESS"))
                        .font(EchoTheme.eyebrow)
                        .tracking(1.5)
                        .foregroundStyle(EchoTheme.terracotta)
                    Spacer()
                    Label("\(coordinator.lesson.durationMinutes) min", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(EchoTheme.secondaryInk)
                }
                Text(coordinator.lesson.title)
                    .font(EchoTheme.title(30))
                Text("Taught by \(coordinator.lesson.makerRelation) \(coordinator.lesson.makerName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EchoTheme.secondaryInk)
                LessonProgressBar(fraction: coordinator.completedFraction)
                Text("\(coordinator.progress.completedStepIDs.count) of \(coordinator.lesson.steps.count) steps complete")
                    .font(.caption)
                    .foregroundStyle(EchoTheme.secondaryInk)
                Button(coordinator.progress.lifecycle == .ready ? "Start Lesson" : "Continue Lesson") {
                    if coordinator.progress.lifecycle == .ready {
                        coordinator.startLesson()
                    } else {
                        coordinator.resumeLesson()
                    }
                }
                .buttonStyle(EchoPrimaryButtonStyle())
            }

            Button(action: coordinator.showHistory) {
                HStack {
                    EchoFeatureIcon(systemName: "clock.arrow.circlepath", color: EchoTheme.sage)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Learning History").font(.headline).foregroundStyle(EchoTheme.ink)
                        Text("Your private progress and completed passes")
                            .font(.caption)
                            .foregroundStyle(EchoTheme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(EchoTheme.secondaryInk)
                }
                .padding(14)
                .background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .accessibilityLabel("Open Learning History")

            Label("Progress is saved on this device", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EchoTheme.sage)
                .frame(maxWidth: .infinity)
        }
    }
}

struct LearningMaterialsView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            LearnHeader(title: "Materials", backTitle: "Learn", onBack: coordinator.showDashboard)
            EchoEyebrow(text: "Before you begin")
            Text("Gather what you need.")
                .font(EchoTheme.title(39))
            Text("Check items for your own reference. You can start even if everything is not ready.")
                .foregroundStyle(EchoTheme.secondaryInk)

            LearnCard {
                ForEach(coordinator.lesson.materials) { material in
                    Button { coordinator.toggleMaterial(material.id) } label: {
                        HStack(spacing: 13) {
                            Image(systemName: coordinator.progress.checkedMaterialIDs.contains(material.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(coordinator.progress.checkedMaterialIDs.contains(material.id) ? EchoTheme.sage : EchoTheme.line)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(material.name).font(.headline).foregroundStyle(EchoTheme.ink)
                                Text(material.detail).font(.caption).foregroundStyle(EchoTheme.secondaryInk)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(material.name)
                    if material.id != coordinator.lesson.materials.last?.id {
                        Divider()
                    }
                }
            }

            Label("Checklist changes stay private to you", systemImage: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EchoTheme.sage)
            Button("Start Step 1", action: coordinator.beginSteps)
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }
}

struct LearningHistoryView: View {
    @ObservedObject var coordinator: LearnCoordinator

    var body: some View {
        EchoScreen {
            LearnHeader(title: "History", backTitle: "Learn", onBack: coordinator.showDashboard)
            EchoEyebrow(text: "Private to you")
            Text("Learning History")
                .font(EchoTheme.title(39))
            Text("A quiet record of what you practiced and carried forward.")
                .foregroundStyle(EchoTheme.secondaryInk)

            if coordinator.learningRecords.isEmpty {
                Text("No learning history yet. Start a lesson to save your place here.").foregroundStyle(EchoTheme.secondaryInk)
            }
            ForEach(coordinator.learningRecords, id: \.lessonID) { record in
                let lesson = coordinator.availableLessons.first { $0.id == record.lessonID }
                Button { coordinator.openHistoryLesson(record.lessonID) } label: {
                    LearnCard {
                        Text(lesson?.title ?? "Unavailable lesson").font(.headline)
                        Text(record.lifecycle == .completed ? "Completed · Pass \(record.passNumber)" : "In progress · Pass \(record.passNumber)")
                            .font(.subheadline).foregroundStyle(EchoTheme.sage)
                        Text("\(record.completedStepIDs.count) of \(lesson?.steps.count ?? 0) steps").font(.caption)
                    }
                }.buttonStyle(.plain).disabled(lesson == nil)
            }

            LearnCard {
                Label("Saved on this device", systemImage: "iphone")
                    .font(.headline)
                Text("Your history remains private and available offline on this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }
        }
    }
}
