import SwiftUI

struct FamilyOverviewView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    var onOpenProfile: (() -> Void)?
    var body: some View {
        EchoScreen {
            HStack {
                Button {
                    if let onOpenProfile { onOpenProfile() } else { coordinator.showProfile() }
                } label: {
                    HStack(spacing: 10) {
                        if let user = coordinator.currentUser { FamilyMemberAvatar(member: user, size: 54) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(coordinator.currentUser?.name ?? "Your profile").font(.headline)
                            Text(coordinator.state.familyName).font(.caption).foregroundStyle(EchoTheme.secondaryInk)
                        }
                    }
                    .foregroundStyle(EchoTheme.ink)
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Profile")
                .accessibilityValue("\(coordinator.currentUser?.name ?? "Your profile"), \(coordinator.currentUser?.avatarFilename == nil ? "Default photo" : "Custom photo")")
                Spacer()
                Button { coordinator.show(.settings) } label: { Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("Family Settings")
            }
            Text("Skills live longer when we keep them together.").font(EchoTheme.title(39)).accessibilityAddTraits(.isHeader)
            Image("FamilyCooking").resizable().scaledToFill().frame(height: 205).clipShape(RoundedRectangle(cornerRadius: 22)).clipped()
                .accessibilityLabel("Family members passing on cooking skills together")
            HStack {
                metric("person.3.fill", "\(coordinator.occupiedFamilySlots)", "members")
                Divider().frame(height: 42)
                metric("book", "\(coordinator.state.sharedLessonCount)", "skills")
                Divider().frame(height: 42)
                metric("hammer", "\(Set(coordinator.librarySkills.map { $0.maker.id }).count)", "makers")
            }.padding().background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 18))
            Button { coordinator.show(.members) } label: { Label("Invite Family", systemImage: "person.badge.plus") }.buttonStyle(EchoPrimaryButtonStyle())
            HStack { EchoSectionTitle(title: "Continue together"); Spacer() }
            if let skill = coordinator.librarySkills.first {
                Button { coordinator.handoff = .learn(skill.id) } label: {
                    EchoCard { VStack(alignment: .leading) { Text(skill.title).font(.headline); Text("Explore a family lesson").foregroundStyle(EchoTheme.secondaryInk) } }
                }.buttonStyle(.plain)
            } else { Button("Create the First Lesson") { coordinator.handoff = .capture }.buttonStyle(EchoSecondaryButtonStyle()) }
            Button { coordinator.show(.familyActivity) } label: { HStack { EchoSectionTitle(title: "Recent family activity"); Spacer(); Text("See All"); Image(systemName: "chevron.right") } }.buttonStyle(.plain)
            ForEach(coordinator.visibleActivity.prefix(2)) { event in
                HStack { Image(RuntimePhotos.cover(event.imageName, title: event.summary)).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle()); VStack(alignment: .leading) { Text(event.memberName).font(.headline); Text(event.summary).font(.subheadline).foregroundStyle(EchoTheme.secondaryInk) }; Spacer(); Text(event.age).font(.caption) }
            }
            Button { coordinator.show(.makerArchive) } label: { HStack { EchoSectionTitle(title: "Our makers"); Spacer(); Text("See All"); Image(systemName: "chevron.right") } }.buttonStyle(.plain)
            HStack { ForEach(coordinator.state.members.filter(\.isMaker)) { member in VStack { FamilyMemberAvatar(member: member, size: 76); Text(member.relation).font(.headline) }.frame(maxWidth: .infinity) } }
            EchoStatusNote(icon: "lock.fill", text: "Private to invited family members.")
        }
    }
    private func metric(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack { Image(systemName: icon).foregroundStyle(EchoTheme.sage); Text(value).font(EchoTheme.title(26)); Text(label).font(.caption).foregroundStyle(EchoTheme.secondaryInk) }.frame(maxWidth: .infinity)
    }
}

struct MembersView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Family", title: "Members", onBack: coordinator.showFamily)
            Text("\(coordinator.occupiedFamilySlots) of 5 family members").font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            EchoStatusNote(icon: "lock.fill", text: "Private Family Space")
            EchoSectionTitle(title: "Family members")
            ForEach(coordinator.state.members) { member in
                Button { coordinator.show(.memberPermissions(member.id)) } label: {
                    EchoCard { HStack { FamilyMemberAvatar(member: member); VStack(alignment: .leading) { Text(member.name).font(.headline); Text("\(member.isMaker ? "Maker · " : "")\(member.role.title)").foregroundStyle(EchoTheme.secondaryInk) }; Spacer(); Image(systemName: "chevron.right") } }
                }.buttonStyle(.plain).accessibilityLabel("Manage \(member.name)")
            }
            ForEach(coordinator.state.invitations) { invite in
                EchoCard { Text(invite.email).font(.headline); Text("Invite expires in 7 days").foregroundStyle(EchoTheme.secondaryInk); HStack { Button("Resend") { coordinator.resendInvitation(invite.id) }.buttonStyle(.borderedProminent); Button("Cancel", role: .destructive) { coordinator.cancelInvitation(invite.id) }.buttonStyle(.bordered) } }
            }
            Button { coordinator.show(.inviteMember) } label: { Label("Invite a Member", systemImage: "person.badge.plus") }.buttonStyle(EchoSecondaryButtonStyle()).disabled(coordinator.occupiedFamilySlots >= 5)
            if coordinator.occupiedFamilySlots >= 5 { EchoStatusNote(icon: "info.circle", text: "Your V1 family is full. Remove a member to invite someone new.", color: EchoTheme.secondaryInk) }
        }
    }
}

struct InviteMemberView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var email = ""
    @State private var name = ""
    @State private var role: FamilyAccessRole = .viewAndLearn
    @State private var resultText: String?
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Members", title: "Bring someone into your family story.", onBack: { coordinator.show(.members) })
            Text("They’ll join \(coordinator.state.familyName) and see only what your permissions allow.").font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            EchoCard {
                Text("Email address").font(.headline); TextField("alex@example.com", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder).accessibilityLabel("Email address")
                Text("Their name (optional)").font(.headline); TextField("Alex", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Their name")
                Text("Choose access").font(.headline)
                ForEach([FamilyAccessRole.viewAndLearn, .contributor], id: \.self) { item in Button { role = item } label: { Label(item.title, systemImage: role == item ? "largecircle.fill.circle" : "circle").frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) }.buttonStyle(.plain) }
                EchoStatusNote(icon: "lock.fill", text: "Private · Invitation expires in 7 days")
                Button("Send Invitation") { send() }.buttonStyle(EchoPrimaryButtonStyle())
                Text("Invitations are saved on this device. Delivery and joining on another device require Family Sync, which is not connected yet.").font(.footnote).foregroundStyle(EchoTheme.secondaryInk)
                if let resultText { Text(resultText).font(.footnote).foregroundStyle(EchoTheme.terracotta).accessibilityIdentifier("Invitation Result") }
            }
        }
    }
    private func send() {
        switch coordinator.sendInvitation(email: email, name: name.isEmpty ? nil : name, role: role) {
        case .sent: resultText = "Invitation saved privately on this device."; coordinator.show(.members)
        case .invalidEmail: resultText = "Enter a valid email address."
        case .familyFull: resultText = "Your family already has five accepted or pending members."
        case .alreadyPending: resultText = "An invitation for this email is already pending."
        }
    }
}

struct MemberPermissionsView: View {
    let memberID: UUID
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var role: FamilyAccessRole = .viewAndLearn
    @State private var selectedOnly = false
    @State private var selectedLesson = false
    @State private var publish = false
    @State private var edit = false
    @State private var invite = false
    @State private var download = false
    @State private var warning: String?
    private var member: FamilyMember? { coordinator.state.members.first { $0.id == memberID } }
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Members", title: "\(member?.name.components(separatedBy: " ").first ?? "Member")’s access", onBack: { coordinator.show(.members) })
            if let member { EchoCard { HStack { FamilyMemberAvatar(member: member, size: 74); VStack(alignment: .leading) { Text(member.name).font(EchoTheme.title(28)); Text(member.email).foregroundStyle(EchoTheme.secondaryInk) } } } }
            EchoSectionTitle(title: "Family role")
            EchoCard { ForEach(FamilyAccessRole.allCases) { item in Button { role = item } label: { Label(item.title, systemImage: role == item ? "largecircle.fill.circle" : "circle").frame(maxWidth: .infinity, minHeight: 46, alignment: .leading) }.buttonStyle(.plain) } }
            EchoSectionTitle(title: "Lesson access")
            EchoCard {
                Button { selectedOnly = false } label: { Label("All family lessons", systemImage: !selectedOnly ? "largecircle.fill.circle" : "circle") }.buttonStyle(.plain).frame(minHeight: 44)
                Button { selectedOnly = true } label: { Label("Selected lessons only", systemImage: selectedOnly ? "largecircle.fill.circle" : "circle") }.buttonStyle(.plain).frame(minHeight: 44)
                if selectedOnly { Toggle("Grandma’s Apple Pie", isOn: $selectedLesson) }
            }
            EchoCard { Toggle("Can publish new lessons", isOn: $publish); Toggle("Can edit own lessons", isOn: $edit); Toggle("Can invite family members", isOn: $invite); Toggle("Can download original videos", isOn: $download) }
            if let warning { Text(warning).foregroundStyle(.red).font(.footnote) }
            Button("Save Changes") { save() }.buttonStyle(EchoPrimaryButtonStyle())
            Button("Remove from Family Space", role: .destructive) { remove() }.buttonStyle(EchoSecondaryButtonStyle())
        }.onAppear { load() }
    }
    private func load() { guard let member else { return }; role = member.role; selectedOnly = member.lessonAccess == .selected; selectedLesson = !member.selectedLessonIDs.isEmpty; publish = member.canPublish; edit = member.canEditOwnLessons; invite = member.canInvite; download = member.canDownloadOriginals }
    private func save() {
        guard coordinator.updateRole(for: memberID, to: role) == .saved else { warning = "At least one organizer must remain."; return }
        let lessonResult = coordinator.updateLessonAccess(for: memberID, mode: selectedOnly ? .selected : .all, lessonIDs: selectedLesson ? ["apple-pie"] : [])
        guard lessonResult == .saved else { warning = "Choose at least one lesson."; return }
        coordinator.updatePermissions(for: memberID, publish: publish, edit: edit, invite: invite, download: download); coordinator.show(.members)
    }
    private func remove() { if coordinator.removeMember(memberID) == .lastOrganizer { warning = "The last organizer cannot leave the Family Space." } else { coordinator.show(.members) } }
}

struct FamilyActivityView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var filter: FamilyActivityKind?
    var filtered: [FamilyActivityEvent] { guard let filter else { return coordinator.visibleActivity }; return coordinator.visibleActivity.filter { $0.kind == filter } }
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Family", title: "Family Activity", onBack: coordinator.showFamily)
            Text("What your invited family has shared.").font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            ScrollView(.horizontal, showsIndicators: false) { HStack { filterButton("All", nil); filterButton("New Lessons", .newLesson); filterButton("Practice", .sharedPractice); filterButton("Milestones", .milestone) } }
            ForEach(filtered) { event in
                Button {
                    if let id = event.lessonID { coordinator.handoff = event.kind == .sharedPractice ? .practice(id) : .learn(id) }
                    else { coordinator.handoff = .library }
                } label: { EchoCard { HStack { Image(RuntimePhotos.cover(event.imageName, title: event.summary)).resizable().scaledToFill().frame(width: 86, height: 74).clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading) { Text(event.memberName).font(.headline); Text(event.summary); Text(event.age).font(.caption).foregroundStyle(EchoTheme.secondaryInk) } } } }.buttonStyle(.plain)
            }
            EchoStatusNote(icon: "lock.fill", text: "Only shared family activity appears here. Personal progress and questions stay private.")
            Button("Activity notifications") { coordinator.show(.notifications) }.buttonStyle(EchoSecondaryButtonStyle())
        }
    }
    private func filterButton(_ title: String, _ value: FamilyActivityKind?) -> some View { Button(title) { filter = value }.buttonStyle(.borderedProminent).tint(filter == value ? EchoTheme.terracotta : EchoTheme.secondaryInk) }
}

struct MakerArchiveView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    var rose: FamilyMember { coordinator.state.members.first(where: { $0.name == "Rose Carter" }) ?? coordinator.state.members[0] }
    var body: some View {
        EchoScreen {
            LibraryBackButton(title: "Family", action: coordinator.showFamily)
            GeometryReader { geometry in
                Image(RuntimePhotos.maker(rose.imageName, relation: rose.relation)).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }.frame(height: 250)
            Text("Grandma Rose").font(EchoTheme.title(43)); Text("Rose Carter · \(coordinator.state.familyName)").font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            Text("Keeper of the recipes and small traditions that bring everyone back to the table.").font(.title3)
            HStack { Text("12 lessons"); Spacer(); Text("4h 18m preserved"); Spacer(); Text("7 learners") }.font(.subheadline).padding().background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 16))
            Button("Learn from Rose") {
                if let skill = coordinator.librarySkills.first(where: { $0.maker.relation == "Grandma" }) { coordinator.handoff = .learn(skill.id) }
                else { coordinator.handoff = .library }
            }.buttonStyle(EchoPrimaryButtonStyle())
            EchoSectionTitle(title: "Her Skills")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                skill("FamilyBaking", "Grandma’s Apple Pie")
                skill("SkillPasta", "Sunday Pasta")
                skill("SkillWreath", "Holiday Wreath")
            }
            EchoSectionTitle(title: "Family memories")
            EchoCard { Text("“Watching Grandma make this pie is a core memory for me. The whole house always smelled like home.”"); Text("— Dad").foregroundStyle(EchoTheme.secondaryInk) }
            EchoStatusNote(icon: "lock.fill", text: "Visible only inside \(coordinator.state.familyName).")
        }
    }
    private func skill(_ image: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                Image(image)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: 86)
            Text(title)
                .font(.caption.bold())
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .background(EchoTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("Skill cover photo")
        .accessibilityIdentifier("maker-skill-\(image)")
    }
}
