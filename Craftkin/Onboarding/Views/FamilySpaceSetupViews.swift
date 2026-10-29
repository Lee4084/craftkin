import SwiftUI

private enum FieldFocus: Hashable {
    case familyName
    case inviteCode
}

struct CreateFamilySpaceView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var familyName = ""
    @State private var validationMessage: String?
    @FocusState private var focus: FieldFocus?

    private var validatedName: String? {
        guard case let .valid(name) = FamilySpaceNameValidator.validate(familyName) else { return nil }
        return name
    }

    private var previewName: String {
        validatedName ?? "Your Family Space"
    }

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            VStack(alignment: .leading, spacing: 7) {
                EchoEyebrow(text: "Create a space")
                Text("Give your family\nlibrary a name.")
                    .font(EchoTheme.title(40))
                    .foregroundStyle(EchoTheme.ink)
                    .accessibilityLabel("Give your family library a name.")
                    .accessibilityAddTraits(.isHeader)
                Text("You can change this anytime.")
                    .font(.title3)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Family Space name")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(EchoTheme.ink)

                TextField("The Carter Family", text: $familyName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focus, equals: .familyName)
                    .font(.title3)
                    .padding(16)
                    .frame(minHeight: 56)
                    .background(EchoTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(validationMessage == nil ? EchoTheme.line : EchoTheme.terracotta, lineWidth: 1)
                    }
                    .accessibilityLabel("Family Space name")
                    .onSubmit { focus = nil }

                HStack {
                    Text(validationMessage ?? "Visible only to invited members.")
                        .foregroundStyle(validationMessage == nil ? EchoTheme.secondaryInk : EchoTheme.terracotta)
                    Spacer()
                    Text("\(familyName.count)/40")
                        .foregroundStyle(familyName.count > 40 ? EchoTheme.terracotta : EchoTheme.secondaryInk)
                }
                .font(.footnote)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Your role")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(EchoTheme.ink)

                Label("You’ll be the Organizer", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(EchoTheme.terracotta)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                Text("The creator role is assigned automatically. Contributor and Viewer roles apply to people you invite later.")
                    .font(.footnote)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Your Family Space")
                    .font(.system(.title3, design: .serif, weight: .bold))

                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(EchoTheme.terracotta)
                        .accessibilityLabel("You, organizer")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("You · Organizer").font(.headline)
                        Label("Invite members after setup", systemImage: "person.badge.plus")
                            .font(.subheadline).foregroundStyle(EchoTheme.secondaryInk)
                    }
                }

                Text(previewName)
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(EchoTheme.ink)
                    .lineLimit(2)
                Label("1 member  ·  Private", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(EchoTheme.sage)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button("Create Family Space") {
                do {
                    try coordinator.completeCreatedSpace(named: familyName)
                } catch {
                    validationMessage = error.localizedDescription
                    focus = .familyName
                }
            }
            .buttonStyle(EchoPrimaryButtonStyle())
            .disabled(validatedName == nil)
            .opacity(validatedName == nil ? 0.45 : 1)

            Text("By continuing, you agree to keep shared family content respectful and consensual.")
                .font(.footnote)
                .foregroundStyle(EchoTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .onChange(of: familyName) { _, _ in validationMessage = nil }
    }
}

struct JoinFamilySpaceView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var rawCode = ""
    @State private var attemptedInvalidCode = false
    @State private var showsLinkHelp = false
    @FocusState private var focus: FieldFocus?

    private var preview: InvitationPreview? {
        LocalInvitationValidator.preview(for: rawCode)
    }

    var body: some View {
        EchoScreen(showsBackButton: true, onBack: coordinator.goBack) {
            VStack(alignment: .leading, spacing: 7) {
                EchoEyebrow(text: "Join a Family Space")
                Text("Learn together,\nfrom anywhere.")
                    .font(EchoTheme.title(40))
                    .foregroundStyle(EchoTheme.ink)
                    .accessibilityLabel("Learn together, from anywhere.")
                    .accessibilityAddTraits(.isHeader)
                Text("Open an invite link or enter the six-character code shared by your family organizer.")
                    .font(.title3)
                    .foregroundStyle(EchoTheme.secondaryInk)
            }

            InvitationPreviewCard(invitation: preview)

            VStack(alignment: .leading, spacing: 9) {
                Text("Invitation code")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(EchoTheme.ink)

                InviteCodeField(code: $rawCode, focus: $focus)

                if attemptedInvalidCode {
                    Text("That invitation code is not available. Check it and try again.")
                        .font(.footnote)
                        .foregroundStyle(EchoTheme.terracotta)
                } else {
                    Text("Try ECHO26 for the local preview.")
                        .font(.footnote)
                        .foregroundStyle(EchoTheme.secondaryInk)
                }
            }

            Button("Join Family Space") {
                guard let preview else {
                    attemptedInvalidCode = true
                    focus = .inviteCode
                    return
                }
                try? coordinator.completeJoinedSpace(preview)
            }
            .buttonStyle(EchoPrimaryButtonStyle())
            .disabled(preview == nil)
            .opacity(preview == nil ? 0.45 : 1)

            HStack(spacing: 12) {
                Rectangle().fill(EchoTheme.line).frame(height: 1)
                Text("OR").font(.footnote.weight(.semibold)).foregroundStyle(EchoTheme.secondaryInk)
                Rectangle().fill(EchoTheme.line).frame(height: 1)
            }

            Button {
                showsLinkHelp = true
            } label: {
                Label("Open Invite Link", systemImage: "link")
            }
            .buttonStyle(EchoSecondaryButtonStyle())

            Label("Only invited members can access this space.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(EchoTheme.secondaryInk)
                .frame(maxWidth: .infinity)
        }
        .onChange(of: rawCode) { _, newValue in
            let filtered = String(
                newValue
                    .filter { $0.isASCII && $0.isLetter || $0.isASCII && $0.isNumber }
                    .prefix(6)
            )
            if filtered != newValue { rawCode = filtered }
            attemptedInvalidCode = filtered.count == 6 && LocalInvitationValidator.preview(for: filtered) == nil
            if LocalInvitationValidator.preview(for: filtered) != nil {
                Task { @MainActor in focus = nil }
            }
        }
        .alert("Open an EchoSkill invite", isPresented: $showsLinkHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tap an EchoSkill invitation link in Messages or Mail. Link activation will open this page and fill the invitation details.")
        }
    }
}

private struct InviteCodeField: View {
    @Binding var code: String
    var focus: FocusState<FieldFocus?>.Binding

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    Text(character(at: index))
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(EchoTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(EchoTheme.paper)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(code.count == index && focus.wrappedValue == .inviteCode ? EchoTheme.terracotta : EchoTheme.line, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .accessibilityHidden(true)
                }
            }

            TextField("", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused(focus, equals: .inviteCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color.clear)
                .accessibilityLabel("Invitation code")
                .onSubmit { focus.wrappedValue = nil }
        }
    }

    private func character(at index: Int) -> String {
        guard code.indices.contains(code.index(code.startIndex, offsetBy: index, limitedBy: code.endIndex) ?? code.endIndex),
              index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)]).uppercased()
    }
}

private struct InvitationPreviewCard: View {
    let invitation: InvitationPreview?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 7) {
                EchoEyebrow(text: invitation == nil ? "Invitation preview" : "You've been invited to")
                Text(invitation?.familyName ?? "Your family appears here")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(EchoTheme.ink)
                    .lineLimit(2)
                Text(invitation.map { "\($0.memberCount) members  ·  \($0.skillCount) skills" } ?? "Enter a valid code to review the private space.")
                    .font(.subheadline)
                    .foregroundStyle(EchoTheme.secondaryInk)

                if invitation != nil {
                    HStack(spacing: -7) {
                        FamilyAvatar(imageName: "FamilySewing")
                        FamilyAvatar(imageName: "SkillWoodwork")
                        FamilyAvatar(imageName: "SkillBikeRepair")
                        FamilyAvatar(imageName: "SkillGardening")
                    }
                    .padding(.top, 4)
                    .accessibilityLabel("Four family members")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .padding(.trailing, 106)

            Image("FamilyWatering")
                .resizable()
                .scaledToFit()
                .frame(width: 142, height: 118)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 174)
        .background(EchoTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EchoTheme.line.opacity(0.6), lineWidth: 1)
        }
    }
}

private struct FamilyAvatar: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay { Circle().stroke(EchoTheme.paper, lineWidth: 2) }
            .accessibilityHidden(true)
    }
}

struct OnboardingCompleteView: View {
    let completion: OnboardingCompletion?
    let onContinueToLibrary: () -> Void

    var body: some View {
        EchoScreen {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(EchoTheme.sageSoft)
                    .frame(width: 164, height: 164)
                Image(systemName: "checkmark")
                    .font(.system(size: 65, weight: .medium))
                    .foregroundStyle(EchoTheme.sage)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(completion?.title ?? "EchoSkill is ready.")
                    .font(EchoTheme.title())
                    .foregroundStyle(EchoTheme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if let name = completion?.spaceName {
                    Text(name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(EchoTheme.terracotta)
                }

                Text("Your setup is saved. Your private Skill Library is ready to open.")
                    .font(.title3)
                    .foregroundStyle(EchoTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity)

            Label("Private by default", systemImage: "lock.fill")
                .font(.headline)
                .foregroundStyle(EchoTheme.sage)
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(EchoTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button("Continue to Library", action: onContinueToLibrary)
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }
}
