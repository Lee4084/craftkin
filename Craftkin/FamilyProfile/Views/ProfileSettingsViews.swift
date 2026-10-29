import SwiftUI
import AVFoundation
import Photos
import UserNotifications

struct MyProfileView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var editsProfile = false
    private var user: FamilyMember { coordinator.currentUser ?? coordinator.state.members[0] }
    var body: some View {
        EchoScreen {
            HStack { Text("My Profile").font(EchoTheme.title(43)); Spacer(); Button { coordinator.show(.settings) } label: { Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("Settings") }
            VStack(spacing: 7) {
                Button { editsProfile = true } label: {
                    FamilyMemberAvatar(member: user, size: 130)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil").foregroundStyle(.white).padding(10)
                                .background(EchoTheme.terracotta).clipShape(Circle())
                        }
                }.buttonStyle(.plain).accessibilityLabel("Edit Profile Photo")
                    .accessibilityValue(user.avatarFilename == nil ? "Default photo" : "Custom photo")
                Text(user.name).font(EchoTheme.title(38))
                Text("Organizer · \(coordinator.state.familyName)").foregroundStyle(EchoTheme.secondaryInk)
                Label(user.email, systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
                Text("Learning the skills I want our family to remember.").padding(.top, 8).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity)
            HStack { profileMetric("\(coordinator.librarySkills.count)", "family lessons"); profileMetric("\(coordinator.state.completedSkillCount)", "skills completed"); profileMetric("\(coordinator.state.sharedPracticeCount)", "shared practices") }
            Button("Edit Profile") { editsProfile = true }.buttonStyle(EchoPrimaryButtonStyle())
            EchoSectionTitle(title: "My learning")
            if let skill = coordinator.latestLearningSkill, let progress = coordinator.latestLearningProgress {
                Button { coordinator.handoff = .learn(skill.id) } label: {
                    EchoCard { VStack(alignment: .leading) { Text(skill.title).font(.headline); Text("\(progress.completedStepIDs.count) steps complete").font(.subheadline) } }
                }.buttonStyle(.plain)
            } else { Text("Start a lesson to save your place here.").foregroundStyle(EchoTheme.secondaryInk) }
            EchoSectionTitle(title: "My contributions")
            Button("View Family Lessons") { coordinator.handoff = .library }.buttonStyle(EchoSecondaryButtonStyle())
            EchoSectionTitle(title: "Account")
            EchoCard {
                EchoRouteRow(icon: "person.3", title: "Family Space", action: coordinator.showFamily)
                Divider(); EchoRouteRow(icon: "clock", title: "Learning History", action: { coordinator.handoff = .learningHistory })
                Divider(); EchoRouteRow(icon: "gearshape", title: "Settings", action: { coordinator.show(.settings) })
            }
            EchoStatusNote(icon: "lock.fill", text: "Your profile is visible only to invited family members.")
        }
        .sheet(isPresented: $editsProfile) {
            ProfileEditView(coordinator: coordinator)
        }
    }
    private func profileMetric(_ value: String, _ title: String) -> some View { VStack { Text(value).font(EchoTheme.title(27)); Text(title).font(.caption).multilineTextAlignment(.center) }.padding(10).frame(maxWidth: .infinity).background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 15)) }
}

struct SettingsView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var editsProfile = false
    @Environment(\.appRootActions) private var rootActions
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Profile", title: "Settings", onBack: coordinator.showProfile)
            Button { editsProfile = true } label: {
                EchoCard { HStack { if let user = coordinator.currentUser { FamilyMemberAvatar(member: user) }; VStack(alignment: .leading) { Text(coordinator.currentUser?.name ?? "Your profile").font(.headline); Text(coordinator.currentUser?.email ?? "Local profile").foregroundStyle(EchoTheme.secondaryInk) }; Spacer(); Image(systemName: "pencil").foregroundStyle(EchoTheme.terracotta) } }
            }.buttonStyle(.plain).accessibilityLabel("Edit Profile")
            settingsSection("APP & STORAGE", [
                ("externaldrive", "Storage", "Media saved on this iPhone", FamilyProfileRoute.storage),
                ("bell", "Notifications", "Learning and family reminders", .notifications)
            ])
            settingsSection("PRIVACY", [
                ("lock", "Privacy & Permissions", "Camera, microphone, photos", .privacy),
                ("externaldrive.badge.person.crop", "Manage My Data", "Export and removal controls", .manageData)
            ])
            settingsSection("SUPPORT", [("questionmark.circle", "Help & Support", "Guides and diagnostics", .help)])
            EchoCard {
                EchoRouteRow(icon: "globe", title: IntegrationConstants.Text.title, subtitle: IntegrationConstants.Text.subtitle) {
                    rootActions?.login()
                }
                .accessibilityIdentifier(IntegrationConstants.Text.entryID)
            }
            EchoEyebrow(text: IntegrationConstants.Text.legal)
            EchoCard { LegalDocumentLinks() }
            Button("Sign Out") { rootActions?.signOut() }.buttonStyle(EchoSecondaryButtonStyle())
            Text("Made for the skills families don’t want to lose.").font(.caption).frame(maxWidth: .infinity).foregroundStyle(EchoTheme.secondaryInk)
        }
        .sheet(isPresented: $editsProfile) { ProfileEditView(coordinator: coordinator) }
    }
    private func settingsSection(_ title: String, _ rows: [(String, String, String, FamilyProfileRoute)]) -> some View {
        VStack(alignment: .leading, spacing: 8) { EchoEyebrow(text: title); EchoCard { ForEach(Array(rows.enumerated()), id: \.offset) { index, row in if index > 0 { Divider() }; EchoRouteRow(icon: row.0, title: row.1, subtitle: row.2, tint: index.isMultiple(of: 2) ? EchoTheme.terracotta : EchoTheme.sage) { coordinator.show(row.3) } } } }
    }
}

struct StorageView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Settings", title: "Storage", onBack: { coordinator.show(.settings) })
            EchoCard { Label("Stored on this iPhone", systemImage: "iphone").font(.headline); Text("Your lessons, source videos, practice attachments, and learning progress are stored on this iPhone.").foregroundStyle(EchoTheme.secondaryInk) }
            EchoCard { Text(ByteCountFormatter.string(fromByteCount: Int64((try? LocalMediaStore().usedBytes()) ?? 0), countStyle: .file) + " of local media").font(EchoTheme.title(32)); Text("Source videos, practice attachments, and profile photos saved by EchoSkill.").font(.subheadline).foregroundStyle(EchoTheme.secondaryInk) }
            EchoCard { Toggle("Download over Wi-Fi only", isOn: Binding(get: { coordinator.state.settings.downloadOnWiFiOnly }, set: coordinator.setWiFiOnly)); Button("Remove All Downloads", role: .destructive) { coordinator.removeDownloads() }.buttonStyle(EchoSecondaryButtonStyle()) }
            EchoSectionTitle(title: "Original Videos")
            EchoCard { Text("Originals stay on this device until you explicitly remove them. Automatic retention cleanup is off.") }
            EchoStatusNote(icon: "exclamationmark.circle", text: "Removing downloads affects only copies on this device. It does not remove family lessons.", color: Color.orange)
        }
    }
}

struct NotificationsView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var authorization = "Checking…"
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Settings", title: "Notifications", onBack: { coordinator.show(.settings) })
            Text("Choose the family moments and learning reminders worth hearing about.").font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            EchoCard { Label("System status: \(authorization)", systemImage: "bell.badge").font(.headline); Button("Open iOS Settings") { openSettings() }.buttonStyle(.bordered) }
            EchoEyebrow(text: "Learning")
            EchoCard { notificationToggle("Return to a lesson", \.returnToLesson); notificationToggle("Processing complete", \.processingComplete); notificationToggle("Practice feedback", \.practiceFeedback) }
            EchoEyebrow(text: "Family")
            EchoCard { notificationToggle("New family lessons", \.newFamilyLessons); notificationToggle("Shared practices", \.sharedPractices); notificationToggle("Family comments", \.familyComments); notificationToggle("Member invitations", \.memberInvitations) }
            EchoCard { Toggle("Show details on Lock Screen", isOn: Binding(get: { coordinator.state.settings.showLockScreenDetails }, set: coordinator.setShowLockScreenDetails)); Text("When off, notifications reveal no family content.").font(.footnote).foregroundStyle(EchoTheme.secondaryInk) }
            Button("Send a Test Notification") { Task { await sendTest() } }.buttonStyle(EchoSecondaryButtonStyle())
        }.task { let settings = await UNUserNotificationCenter.current().notificationSettings(); authorization = settings.authorizationStatus == .authorized ? "Allowed" : (settings.authorizationStatus == .denied ? "Not Allowed" : "Not Requested") }
    }
    private func notificationToggle(_ title: String, _ keyPath: WritableKeyPath<FamilySettings, Bool>) -> some View { Toggle(title, isOn: Binding(get: { coordinator.state.settings[keyPath: keyPath] }, set: { coordinator.setNotification(keyPath, enabled: $0) })) }
    private func sendTest() async {
        do {
            let center = UNUserNotificationCenter.current()
            let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard allowed else { authorization = "Not Allowed"; coordinator.notice = "Enable notifications in iOS Settings to receive a test."; return }
            authorization = "Allowed"
            let content = UNMutableNotificationContent()
            content.title = "EchoSkill"
            content.body = "Your test reminder is ready."
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: "echoskill.test", content: content,
                                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))
            coordinator.notice = "Test reminder scheduled. Background the app to see it."
        } catch { coordinator.notice = "The reminder could not be scheduled. Please try again." }
    }
    private func openSettings() { guard let url = URL(string: UIApplication.openSettingsURLString) else { return }; UIApplication.shared.open(url) }
}

struct PrivacyPermissionsView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var camera = "Checking…"
    @State private var microphone = "Checking…"
    @State private var photos = "Checking…"
    @State private var notifications = "Checking…"
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Settings", title: "Privacy & Permissions", onBack: { coordinator.show(.settings) })
            EchoStatusNote(icon: "lock.shield.fill", text: "Your family memories stay private. EchoSkill shares content only with people you invite.")
            EchoEyebrow(text: "Device access")
            EchoCard { permission("camera", "Camera", camera); Divider(); permission("mic", "Microphone", microphone); Divider(); permission("photo", "Photos", photos); Divider(); permission("bell", "Notifications", notifications) }
            EchoEyebrow(text: "AI processing")
            EchoCard { Toggle("Create lesson drafts with AI", isOn: .constant(false)).disabled(true); Text("Automatic transcription is not connected. You can record or import a video and write the transcript and steps manually.").font(.footnote).foregroundStyle(EchoTheme.secondaryInk); Divider(); Toggle("Help improve EchoSkill", isOn: .constant(false)).disabled(true); Text("Family media and transcripts are never used for model training in this build.").font(.footnote).foregroundStyle(EchoTheme.secondaryInk) }
            EchoEyebrow(text: "Family visibility")
            EchoCard { EchoRouteRow(icon: "person.3", title: "Default lesson access", subtitle: "View and learn", action: { coordinator.show(.members) }); Divider(); EchoRouteRow(icon: "square.and.arrow.up", title: "Practice sharing", subtitle: "Ask every time", action: { coordinator.notice = "Practice sharing always asks before sharing." }); Divider(); Text("Lock Screen previews · \(coordinator.state.settings.showLockScreenDetails ? "Shown" : "Hidden")") }
            EchoStatusNote(icon: "checkmark.circle.fill", text: "Questions, personal progress, and draft lessons are private by default.")
        }.task { refreshPermissions() }
    }
    private func permission(_ icon: String, _ title: String, _ state: String) -> some View { Button { openSettings() } label: { HStack { Image(systemName: icon).foregroundStyle(EchoTheme.terracotta).frame(width: 34); Text(title).font(.headline); Spacer(); Text(state).font(.subheadline).foregroundStyle(EchoTheme.sage); Image(systemName: "chevron.right") }.frame(minHeight: 48) }.buttonStyle(.plain) }
    private func refreshPermissions() {
        camera = permissionLabel(AVCaptureDevice.authorizationStatus(for: .video))
        microphone = permissionLabel(AVCaptureDevice.authorizationStatus(for: .audio))
        let photoState = PHPhotoLibrary.authorizationStatus(for: .readWrite); photos = photoState == .authorized ? "Allowed" : (photoState == .limited ? "Selected Photos" : (photoState == .denied || photoState == .restricted ? "Not Allowed" : "Not Requested"))
        Task { let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus; notifications = status == .authorized ? "Allowed" : (status == .denied ? "Not Allowed" : "Not Requested") }
    }
    private func permissionLabel(_ status: AVAuthorizationStatus) -> String { switch status { case .authorized: "Allowed"; case .denied, .restricted: "Not Allowed"; case .notDetermined: "Not Requested"; @unknown default: "Unknown" } }
    private func openSettings() { guard let url = URL(string: UIApplication.openSettingsURLString) else { return }; UIApplication.shared.open(url) }
}
