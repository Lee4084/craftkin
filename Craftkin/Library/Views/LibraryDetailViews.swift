import SwiftUI

struct SkillDetailView: View {
    let skill: SkillLesson
    @ObservedObject var coordinator: LibraryCoordinator
    var onContinueLearning: (SkillLesson) -> Void = { _ in }
    var onAskQuestion: (SkillLesson) -> Void = { _ in }
    var onSelectStep: (SkillLesson, String) -> Void = { _, _ in }
    @State private var showsActions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    LibraryBackButton(title: coordinator.backTitle, action: coordinator.goBack)
                    Spacer()
                    Button { showsActions = true } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44).background(EchoTheme.paper).clipShape(Circle())
                    }
                    .accessibilityLabel("Lesson actions")
                }
                .contentShape(Rectangle())
                .zIndex(2)

                GeometryReader { geometry in
                    Image(skill.coverImageName)
                        .resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 23))
                        .allowsHitTesting(false)
                }
                .frame(height: 255)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel("\(skill.title) cover")

                EchoEyebrow(text: skill.category)
                Text(skill.title).font(EchoTheme.title(38)).accessibilityAddTraits(.isHeader)

                HStack(spacing: 12) {
                    Button { coordinator.showMaker(skill.maker.id) } label: {
                        HStack(spacing: 10) {
                            MakerAvatar(maker: skill.maker, size: 50)
                            VStack(alignment: .leading) {
                                Text("Taught by \(skill.maker.relation)").font(.system(.headline, design: .serif, weight: .bold))
                                Text(skill.maker.name).font(.caption).foregroundStyle(EchoTheme.secondaryInk)
                            }
                        }
                    }
                    .buttonStyle(.plain).foregroundStyle(EchoTheme.ink)
                    .accessibilityLabel("\(skill.maker.relation) profile")
                    Spacer()
                    ProgressBadge(progress: skill.progress)
                }

                HStack {
                    Label("\(skill.stepCount) steps", systemImage: "list.bullet")
                    Spacer()
                    Label("\(skill.durationMinutes) min", systemImage: "clock")
                    Spacer()
                    Label("\(skill.completedSteps) completed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(EchoTheme.sage)
                }
                .font(.subheadline.weight(.semibold)).padding(14).background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 17))

                Button("Continue Learning") { onContinueLearning(skill) }
                    .buttonStyle(EchoPrimaryButtonStyle())
                Button("Ask About This Skill") { onAskQuestion(skill) }
                    .buttonStyle(EchoSecondaryButtonStyle())

                Text("What You’ll Need").font(EchoTheme.title(29))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(skill.materials + skill.tools, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                                .font(.subheadline).padding(.horizontal, 13).frame(minHeight: 42)
                                .background(EchoTheme.paper).clipShape(Capsule())
                        }
                    }
                }

                Text("Lesson Steps").font(EchoTheme.title(29))
                ForEach(Array(skill.steps.enumerated()), id: \.element.id) { index, step in
                    Button { onSelectStep(skill, step.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "\(index + 1).circle.fill")
                                .font(.title2).foregroundStyle(step.isComplete ? EchoTheme.sage : EchoTheme.terracotta)
                            Text(step.title).font(.system(.headline, design: .serif))
                            Spacer()
                            Text("\(step.minutes) min").font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(EchoTheme.ink).padding(13).background(EchoTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    MakerAvatar(maker: skill.maker, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(skill.maker.relation)’s Note").font(.system(.headline, design: .serif, weight: .bold))
                        Text("“\(skill.transcript)”").font(.system(.body, design: .serif)).italic()
                    }
                }
                .padding(14).background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("Lesson actions", isPresented: $showsActions, titleVisibility: .visible) {
            Button("Continue Learning") { onContinueLearning(skill) }
            Button("Ask About This Skill") { onAskQuestion(skill) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct MakerProfileView: View {
    let maker: FamilyMaker
    @ObservedObject var coordinator: LibraryCoordinator
    var onRecord: (FamilyMaker) -> Void = { _ in }
    @State private var showsMemoryEditor = false
    @State private var memory = ""
    @State private var memoryError: String?

    private var makerSkills: [SkillLesson] { coordinator.skills(for: maker) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    LibraryBackButton(title: coordinator.backTitle, action: coordinator.goBack)
                    Spacer()
                    Button { showsMemoryEditor = true } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44).background(EchoTheme.paper).clipShape(Circle())
                    }
                }
                .contentShape(Rectangle())
                .zIndex(2)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 18) {
                        MakerAvatar(maker: maker, size: 142)
                        makerIdentity
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        MakerAvatar(maker: maker, size: 130)
                        makerIdentity
                    }
                }

                HStack {
                    Statistic(value: "\(makerSkills.count)", label: "Skills")
                    Divider()
                    Statistic(value: "4", label: "Family Learners")
                    Divider()
                    Statistic(value: "\(makerSkills.filter { $0.progress == .completed }.count)", label: "Completed")
                }
                .frame(height: 80).padding(.horizontal, 12).background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button("Record with \(maker.relation)") { onRecord(maker) }
                    .buttonStyle(EchoPrimaryButtonStyle())
                Button("Add a Memory") { showsMemoryEditor = true }
                    .buttonStyle(EchoSecondaryButtonStyle())

                Text("Skills from \(maker.relation)").font(EchoTheme.title(29))
                if makerSkills.isEmpty {
                    Text("No lessons have been saved for this maker yet.").foregroundStyle(EchoTheme.secondaryInk)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(makerSkills) { skill in
                                SkillGridCard(skill: skill) { coordinator.showSkill(skill.id) }
                                    .frame(width: 190)
                            }
                        }
                    }
                }

                Text("Her Story").font(EchoTheme.title(29))
                Image(RuntimePhotos.maker(maker.imageName, relation: maker.relation)).resizable().scaledToFill().frame(height: 190).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .accessibilityLabel("\(maker.name) sharing time with family")
                Text(maker.story).font(.system(.title3, design: .serif)).lineSpacing(3)
                ForEach(Array((coordinator.makerMemories[maker.id] ?? []).enumerated()), id: \.offset) { _, note in
                    Text(note).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Text("Private Family Space").font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsMemoryEditor) {
            NavigationStack {
                Form {
                    TextEditor(text: $memory).frame(minHeight: 160).accessibilityLabel("Family memory")
                    Text("\(memory.count)/2000").font(.caption)
                    if let memoryError { Text(memoryError).foregroundStyle(.red) }
                }.navigationTitle("Add a Memory")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsMemoryEditor = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Save") {
                            if coordinator.saveMemory(memory, for: maker.id) { memory = ""; memoryError = nil; showsMemoryEditor = false }
                            else { memoryError = "Enter a memory of 1 to 2,000 characters and try again." }
                        } }
                    }
            }
        }
    }

    private var makerIdentity: some View {
        VStack(alignment: .leading, spacing: 7) {
            EchoEyebrow(text: maker.relation)
            Text(maker.name).font(EchoTheme.title(34)).accessibilityAddTraits(.isHeader)
            Text(maker.roles).font(.headline).foregroundStyle(EchoTheme.secondaryInk)
            Text("“\(maker.quote)”").font(.system(.title3, design: .serif)).italic()
        }
    }
}

private struct Statistic: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.title, design: .serif, weight: .bold))
            Text(label).font(.caption).foregroundStyle(EchoTheme.secondaryInk).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }
}

private struct ProgressBadge: View {
    let progress: SkillProgress

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 10).frame(minHeight: 36)
            .background(color.opacity(0.12)).clipShape(Capsule())
    }

    private var title: String {
        switch progress {
        case .new: "New"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        case .saved: "Saved"
        }
    }

    private var icon: String {
        switch progress {
        case .new: "sparkles"
        case .inProgress: "circle.dotted"
        case .completed: "checkmark.circle.fill"
        case .saved: "bookmark.fill"
        }
    }

    private var color: Color {
        progress == .new ? EchoTheme.terracotta : EchoTheme.sage
    }
}
