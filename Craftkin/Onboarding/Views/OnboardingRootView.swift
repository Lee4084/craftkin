import SwiftUI

struct OnboardingRootView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let isCloudAvailable: Bool
    let onContinueToLibrary: () -> Void

    var body: some View {
        Group {
            switch coordinator.step {
            case .welcome:
                WelcomeView(coordinator: coordinator)
            case .howItWorks:
                HowItWorksView(coordinator: coordinator)
            case .privacy:
                PrivacyView(coordinator: coordinator)
            case .familySpaceChoice:
                FamilySpaceChoiceView(coordinator: coordinator, isCloudAvailable: isCloudAvailable)
            case .createFamilySpace:
                CreateFamilySpaceView(coordinator: coordinator)
            case .joinFamilySpace:
                JoinFamilySpaceView(coordinator: coordinator)
            case .complete:
                OnboardingCompleteView(
                    completion: coordinator.completion,
                    onContinueToLibrary: onContinueToLibrary
                )
            }
        }
        .animation(.easeInOut(duration: 0.24), value: coordinator.step)
    }
}

private struct WelcomeView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        EchoScreen {
            EchoBrand()

            GeometryReader { geometry in
                Image("FamilyCooking")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .frame(height: 338)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel("Family members preparing a meal together")

            VStack(spacing: 10) {
                Text("Keep family\nknow-how alive.")
                    .font(EchoTheme.title(42))
                    .foregroundStyle(EchoTheme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Keep family know-how alive.")
                    .accessibilityAddTraits(.isHeader)

                Text("Turn the moments you record into lessons your family can learn for years.")
                    .font(.title3)
                    .foregroundStyle(EchoTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity)

            Button(action: coordinator.getStarted) {
                HStack {
                    Spacer()
                    Text("Get Started")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(EchoPrimaryButtonStyle())

            Button("I have an invite", action: coordinator.openInvite)
                .font(.headline)
                .foregroundStyle(EchoTheme.sage)
                .underline()
                .frame(maxWidth: .infinity, minHeight: 44)

            EchoPageDots(selected: 0)

            Label("Private by default", systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(EchoTheme.secondaryInk)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct HowStep {
    let number: Int
    let icon: String
    let title: String
    let detail: String
    let imageName: String
}

private struct HowItWorksView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    private let steps = [
        HowStep(number: 1, icon: "video.fill", title: "Record it", detail: "Film a family member sharing a skill.", imageName: "FamilyBaking"),
        HowStep(number: 2, icon: "doc.badge.gearshape", title: "Review the draft", detail: "Edit the transcript, tools, and steps.", imageName: "SkillBikeRepair"),
        HowStep(number: 3, icon: "person.2.fill", title: "Learn together", detail: "Follow each step, ask questions, and practice.", imageName: "SkillWoodwork")
    ]

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            VStack(alignment: .leading, spacing: 6) {
                EchoEyebrow(text: "How it works")
                Text("From memory\nto lesson.")
                    .font(EchoTheme.title(40))
                    .foregroundStyle(EchoTheme.ink)
                    .accessibilityLabel("From memory to lesson.")
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 12) {
                ForEach(steps, id: \.number) { step in
                    HowStepCard(step: step)
                }
            }

            EchoPageDots(selected: 1)

            Button("Continue", action: coordinator.continueFromHowItWorks)
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }
}

private struct HowStepCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let step: HowStep

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    stepCopy
                    stepImage.frame(height: 190)
                }
            } else {
                HStack(spacing: 0) {
                    stepCopy
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 8)
                    stepImage
                        .frame(width: 158, height: 132)
                }
            }
        }
        .padding(10)
        .background(EchoTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EchoTheme.line.opacity(0.7), lineWidth: 1)
        }
    }

    private var stepCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Text("\(step.number)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(EchoTheme.terracotta)
                    .clipShape(Circle())
                Image(systemName: step.icon)
                    .foregroundStyle(EchoTheme.terracotta)
                    .font(.title3)
            }
            Text(step.title)
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(EchoTheme.ink)
            Text(step.detail)
                .font(.subheadline)
                .foregroundStyle(EchoTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepImage: some View {
        GeometryReader { geometry in
            Image(step.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel(step.number == 1 ? "A family member teaching a child to bake" : step.number == 2 ? "A family member teaching a child bicycle repair" : "An older family member teaching a child woodworking")
        }
    }
}

private struct PrivacyView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var showsPrivacyDetails = false

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            VStack(alignment: .leading, spacing: 6) {
                EchoEyebrow(text: "Your family, your control")
                Text("Your family stories\nstay private.")
                    .font(EchoTheme.title(36))
                    .foregroundStyle(EchoTheme.ink)
                    .accessibilityLabel("Your family stories stay private.")
                    .accessibilityAddTraits(.isHeader)
                Text("Only the people you invite can see your lessons.")
                    .font(.title3)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }

            Image("FamilySewing")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 165)
                .accessibilityLabel("An older family member teaching a child to sew")

            VStack(spacing: 8) {
                PrivacyRow(icon: "person.3.fill", color: EchoTheme.terracotta, title: "Private by default", detail: "Nothing is shared publicly.")
                PrivacyRow(icon: "doc.badge.gearshape", color: EchoTheme.sage, title: "You approve every draft", detail: "AI suggestions stay editable.")
                PrivacyRow(icon: "square.and.arrow.down", color: EchoTheme.terracotta, title: "Delete or export anytime", detail: "Your family keeps control.")
            }

            Label("Videos stay in your private Family Space.", systemImage: "shield.lefthalf.filled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EchoTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(EchoTheme.sageSoft.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            EchoPageDots(selected: 2)

            Button("Set Up My Space", action: coordinator.setUpMySpace)
                .buttonStyle(EchoPrimaryButtonStyle())

            Button("Learn about privacy") { showsPrivacyDetails = true }
                .font(.headline)
                .underline()
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .sheet(isPresented: $showsPrivacyDetails) {
            PrivacyDetailsView()
                .presentationDetents([.medium, .large])
        }
    }
}

private struct PrivacyRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            EchoFeatureIcon(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(EchoTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PrivacyDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(IntegrationConstants.Text.legal) { LegalDocumentLinks() }
                Section("Storage") {
                    Label("Lessons stay local until you choose a Family Space.", systemImage: "iphone")
                    Label("A future sync service will disclose its storage location before upload.", systemImage: "icloud")
                }
                Section("AI processing") {
                    Label("AI suggestions are drafts. You review them before saving.", systemImage: "wand.and.stars")
                    Label("EchoSkill never publishes family recordings publicly.", systemImage: "eye.slash")
                }
                Section("Invitations and control") {
                    Label("Only people you invite can enter a Family Space.", systemImage: "person.2.badge.key")
                    Label("Export and deletion controls will live in Settings.", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("Privacy at EchoSkill")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct FamilySpaceChoiceView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let isCloudAvailable: Bool
    @State private var showsCloudExplanation = false

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            VStack(alignment: .leading, spacing: 7) {
                EchoEyebrow(text: "Family Space")
                Text("Who will you\nlearn with?")
                    .font(EchoTheme.title(42))
                    .foregroundStyle(EchoTheme.ink)
                    .accessibilityLabel("Who will you learn with?")
                    .accessibilityAddTraits(.isHeader)
                Text("Create a private space for your family, or join one you have been invited to.")
                    .font(.title3)
                    .foregroundStyle(EchoTheme.secondaryInk)
                    .lineSpacing(3)
            }

            FamilyChoiceCard(
                icon: "house.and.flag.fill",
                title: "Create a Family Space",
                subtitle: "Start a new private library and invite family later.",
                accent: EchoTheme.terracotta,
                badge: "Recommended",
                accessibilityName: "Create a Family Space"
            ) {
                isCloudAvailable ? coordinator.openCreateSpace() : (showsCloudExplanation = true)
            }

            FamilyChoiceCard(
                icon: "envelope.badge.person.crop.fill",
                title: "Join with an Invite",
                subtitle: "Use a link or invitation code from a family member.",
                accent: EchoTheme.sage,
                accessibilityName: "Join a Family Space"
            ) {
                isCloudAvailable ? coordinator.openJoinSpace() : (showsCloudExplanation = true)
            }

            Button("Set up later", action: coordinator.setUpLater)
                .font(.headline)
                .foregroundStyle(EchoTheme.terracotta)
                .underline()
                .frame(maxWidth: .infinity, minHeight: 44)

            Label(
                isCloudAvailable ? "Your space can sync securely across your Apple devices." : "iCloud is unavailable. You can continue locally.",
                systemImage: isCloudAvailable ? "icloud" : "icloud.slash"
            )
            .font(.footnote)
            .foregroundStyle(EchoTheme.secondaryInk)
            .frame(maxWidth: .infinity)
        }
        .alert("iCloud is unavailable", isPresented: $showsCloudExplanation) {
            Button("Use Locally", action: coordinator.setUpLater)
            Button("OK", role: .cancel) {}
        } message: {
            Text("Family Spaces need iCloud. You can keep using EchoSkill privately on this device.")
        }
    }
}

private struct FamilyChoiceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    var badge: String? = nil
    let accessibilityName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(accent)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(EchoTheme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(EchoTheme.secondaryInk)
                        .multilineTextAlignment(.leading)
                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EchoTheme.terracotta)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(EchoTheme.terracottaSoft)
                            .clipShape(Capsule())
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(EchoTheme.secondaryInk)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityHint(subtitle)
    }
}
