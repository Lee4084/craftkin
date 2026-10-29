import SwiftUI

struct TranscriptReviewView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    @State private var isEditing = false
    @State private var sourcePosition: TimeInterval = 0
    @State private var sourceSeekToken = 0

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Transcript Review")
            if let filename = coordinator.draft.sourceMediaFilename {
                SourceVideoView(filename: filename, seekPosition: sourcePosition, seekToken: sourceSeekToken)
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    EchoEyebrow(text: "Step 1 of 4")
                    Text("Keep their words true.").font(EchoTheme.title(36)).accessibilityAddTraits(.isHeader)
                }
                Spacer()
                CaptureStatusPill(text: "1 word to check", icon: "exclamationmark.bubble.fill", color: EchoTheme.terracotta)
            }
            Text("Tap a passage to revisit that moment. Edit anything that does not sound like the maker.")
                .foregroundStyle(EchoTheme.secondaryInk)

            ForEach($coordinator.draft.transcript) { $segment in
                CaptureCard {
                    HStack {
                        Button { sourcePosition = segment.start; sourceSeekToken += 1 } label: {
                            Label(segment.start.echoTimestamp, systemImage: "play.circle.fill").foregroundStyle(EchoTheme.terracotta)
                        }.disabled(coordinator.draft.sourceMediaFilename == nil)
                        Spacer()
                        Text(segment.speaker).font(.caption.weight(.semibold)).foregroundStyle(EchoTheme.secondaryInk)
                        if segment.needsReview { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(EchoTheme.terracotta) }
                    }
                    if isEditing {
                        TextEditor(text: $segment.text).frame(minHeight: 72)
                    } else {
                        Text(segment.text.isEmpty ? "Tap Edit Transcript to add the maker’s words." : segment.text).font(.system(.body, design: .serif)).lineSpacing(4)
                    }
                }
            }

            Button(isEditing ? "Finish Editing" : "Edit Transcript") { isEditing.toggle() }
                .buttonStyle(EchoSecondaryButtonStyle())
            Button("Approve Transcript") { coordinator.approveTranscript() }
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }
}

struct MaterialsReviewView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    @State private var selection = 0

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Materials Review")
            EchoEyebrow(text: "Step 2 of 4")
            Text("Gather what they use.").font(EchoTheme.title(36)).accessibilityAddTraits(.isHeader)
            Text("Quantities come from the recording. Leave them blank when the maker did not specify one.")
                .foregroundStyle(EchoTheme.secondaryInk)

            Picker("Material type", selection: $selection) {
                Text("Ingredients").tag(0)
                Text("Tools").tag(1)
            }
            .pickerStyle(.segmented)

            if selection == 0 {
                itemList(items: $coordinator.draft.ingredients, emptyName: "New ingredient")
            } else {
                itemList(items: $coordinator.draft.tools, emptyName: "New tool")
            }

            Button("Approve Materials") { coordinator.approveMaterials() }
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }

    private func itemList(items: Binding<[LessonDraftItem]>, emptyName: String) -> some View {
        VStack(spacing: 12) {
            ForEach(items) { $item in
                CaptureCard {
                    HStack {
                        Image(systemName: "line.3.horizontal").foregroundStyle(EchoTheme.secondaryInk)
                        TextField("Item", text: $item.name).font(.headline)
                        if let sourceTime = item.sourceTime {
                            Text(sourceTime.echoTimestamp).font(.caption.monospacedDigit()).foregroundStyle(EchoTheme.terracotta)
                        }
                    }
                    TextField("Quantity (optional)", text: $item.quantity)
                        .font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
                }
            }
            Button {
                items.wrappedValue.append(
                    LessonDraftItem(id: UUID().uuidString, name: emptyName, quantity: "", sourceTime: nil)
                )
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
            }
            .buttonStyle(EchoSecondaryButtonStyle())
        }
    }
}

struct StepsEditorView: View {
    @ObservedObject var coordinator: CaptureCoordinator

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Steps Editor")
            EchoEyebrow(text: "Step 3 of 4")
            Text("Shape the lesson together.").font(EchoTheme.title(36)).accessibilityAddTraits(.isHeader)
            Text("Rename, reorder and check every key moment before the lesson reaches your family.")
                .foregroundStyle(EchoTheme.secondaryInk)

            ForEach(Array(coordinator.draft.steps.indices), id: \.self) { index in
                stepCard(index: index)
            }

            Button(action: coordinator.addStep) {
                Label("Add Step", systemImage: "plus.circle.fill")
            }
            .buttonStyle(EchoSecondaryButtonStyle())

            Button("Preview Lesson", action: coordinator.previewLesson)
                .buttonStyle(EchoSecondaryButtonStyle())
            Button("Approve Steps") { coordinator.approveSteps() }
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }

    private func stepCard(index: Int) -> some View {
        let step = coordinator.draft.steps[index]
        return CaptureCard {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").font(.headline).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(EchoTheme.terracotta).clipShape(Circle())
                VStack(alignment: .leading, spacing: 7) {
                    TextField("Step title", text: $coordinator.draft.steps[index].title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                    TextField("Instruction", text: $coordinator.draft.steps[index].instruction, axis: .vertical)
                        .font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
                    Label("\(step.start.echoTimestamp) – \(step.end.echoTimestamp)", systemImage: "clock")
                        .font(.caption.weight(.semibold)).foregroundStyle(EchoTheme.secondaryInk)
                }
                Spacer()
                VStack {
                    Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }.disabled(index == 0)
                    Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }.disabled(index == coordinator.draft.steps.count - 1)
                }
            }
            if !step.keyMomentReviewed {
                Button("Review Key Moment") { coordinator.draft.steps[index].keyMomentReviewed = true }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.terracotta)
            }
            HStack {
                VStack(alignment: .leading) { Text("Start (seconds)").font(.caption); TextField("Start", value: $coordinator.draft.steps[index].start, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder) }
                VStack(alignment: .leading) { Text("End (seconds)").font(.caption); TextField("End", value: $coordinator.draft.steps[index].end, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder) }
            }
            if coordinator.draft.steps.count > 1 {
                Button("Remove Step", role: .destructive) { coordinator.draft.steps.remove(at: index) }.frame(minHeight: 44)
            }
        }
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard coordinator.draft.steps.indices.contains(destination) else { return }
        coordinator.draft.steps.swapAt(index, destination)
    }
}

struct CoverSharingView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    private var covers: [String] {
        let current = RuntimePhotos.cover(coordinator.draft.selectedCover, title: coordinator.draft.title)
        // Keep library-photo positions stable while selection changes. A retained
        // legacy/custom cover may appear last, but never moves the photo choices.
        return RuntimePhotos.captureCovers.contains(current)
            ? RuntimePhotos.captureCovers : RuntimePhotos.captureCovers + [current]
    }

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Cover & Sharing")
            EchoEyebrow(text: "Step 4 of 4")
            Text("Ready for your family.").font(EchoTheme.title(38)).accessibilityAddTraits(.isHeader)
            Text("Choose an illustrative cover photo and confirm exactly what family members can do. These library photos are not frames from your video.")
                .foregroundStyle(EchoTheme.secondaryInk)

            Text("Choose a cover").font(.system(.title3, design: .serif, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(covers, id: \.self) { cover in
                        Button { coordinator.draft.selectedCover = cover } label: {
                            Image(cover).resizable().scaledToFill().frame(width: 156, height: 108).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 17))
                                .overlay { RoundedRectangle(cornerRadius: 17).stroke(coordinator.draft.selectedCover == cover ? EchoTheme.terracotta : .clear, lineWidth: 4) }
                                .contentShape(RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cover photo \(covers.firstIndex(of: cover)! + 1)")
                        .accessibilityValue(coordinator.draft.selectedCover == cover ? "Selected" : "Not selected")
                    }
                }
            }

            CaptureCard {
                Text(coordinator.draft.title).font(.system(.title2, design: .serif, weight: .bold))
                Label("Transcript approved", systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
                Label("Materials approved", systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
                Label("\(coordinator.draft.steps.count) steps approved", systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
            }

            Picker("Family access", selection: $coordinator.draft.familyAccess) {
                Text("View and Learn").tag("View and Learn")
                Text("Can Contribute").tag("Can Contribute")
            }
            .pickerStyle(.segmented)
            Toggle("Allow lesson questions", isOn: $coordinator.draft.allowsQuestions).font(.headline).tint(EchoTheme.terracotta)

            CaptureCard {
                Label("The Carter Family", systemImage: "person.2.fill").font(.headline)
                Text("Private Family Space · never posted publicly").font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
            }

            Button("Preview Lesson", action: coordinator.previewLesson)
                .buttonStyle(EchoSecondaryButtonStyle())
            Button("Publish to Family Space") { coordinator.publish() }
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }
}

struct PublishSuccessView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    let onViewLesson: () -> Void
    let onGoToLibrary: () -> Void

    var body: some View {
        EchoScreen {
            Spacer(minLength: 45)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 96)).foregroundStyle(EchoTheme.sage).frame(maxWidth: .infinity)
            EchoEyebrow(text: "Published privately")
                .frame(maxWidth: .infinity)
            Text("A family skill lives on.").font(EchoTheme.title(41)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Text("\(coordinator.draft.title) is now ready for your family to watch, learn and revisit.")
                .font(.title3).foregroundStyle(EchoTheme.secondaryInk).multilineTextAlignment(.center)
            CaptureCard {
                Image(coordinator.draft.selectedCover).resizable().scaledToFill().frame(height: 176).clipped().clipShape(RoundedRectangle(cornerRadius: 17))
                Text(coordinator.draft.title).font(.system(.title2, design: .serif, weight: .bold))
                Label("Shared with The Carter Family", systemImage: "lock.fill").foregroundStyle(EchoTheme.sage)
            }
            Button("View Lesson", action: onViewLesson).buttonStyle(EchoPrimaryButtonStyle())
            Button("Record Another Skill") { coordinator.startAnother() }.buttonStyle(EchoSecondaryButtonStyle())
            Button("Go to Library", action: onGoToLibrary)
                .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
        }
    }
}

struct ProcessingRecoveryView: View {
    @ObservedObject var coordinator: CaptureCoordinator

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            CaptureHeader(title: "Draft Needs Attention")
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 76)).foregroundStyle(EchoTheme.terracotta).frame(maxWidth: .infinity).padding(.top, 20)
            EchoEyebrow(text: "Your video is safe")
            Text("We couldn't finish one part.").font(EchoTheme.title(38)).accessibilityAddTraits(.isHeader)
            Text("The transcript paused around 0:18–0:43. The source video and completed work are still saved.")
                .font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            CaptureCard {
                Label("Source video retained", systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
                Label("Only transcript will retry", systemImage: "arrow.clockwise.circle.fill").foregroundStyle(EchoTheme.terracotta)
                Label("No family member can see this draft", systemImage: "lock.fill").foregroundStyle(EchoTheme.secondaryInk)
            }
            Button("Try Transcript Again") { coordinator.retryTranscript() }.buttonStyle(EchoPrimaryButtonStyle())
            Button("Edit Transcript Manually") { coordinator.editTranscriptManually() }.buttonStyle(EchoSecondaryButtonStyle())
            Button("Replace Video") { coordinator.importSampleVideo() }
                .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
        }
    }
}
