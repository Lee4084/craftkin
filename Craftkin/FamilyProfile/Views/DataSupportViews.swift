import SwiftUI

struct ManageDataView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var includeMedia = false
    @State private var confirmHistory = false
    @State private var confirmPractices = false
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Settings", title: "Manage My Data", onBack: { coordinator.show(.settings) })
            Text("Export a copy or remove information you no longer want EchoSkill to keep.").font(.title3).foregroundStyle(EchoTheme.secondaryInk)
            EchoEyebrow(text: "Export")
            EchoCard {
                Label("Export My Data", systemImage: "square.and.arrow.down").font(EchoTheme.title(26))
                Text("Includes your profile, created lessons, learning history, and practice metadata as a JSON file.")
                Toggle("Add local media (up to 25 MB)", isOn: $includeMedia)
                Text("Media is embedded in the file. Save exports only to a location you trust.").font(.footnote)
                Button("Prepare Export") { coordinator.prepareExport(includeMedia: includeMedia) }.buttonStyle(EchoSecondaryButtonStyle())
                if let url = coordinator.exportURL {
                    ShareLink("Save or Share Export", item: url).buttonStyle(EchoPrimaryButtonStyle())
                }
            }
            EchoEyebrow(text: "Remove")
            EchoCard {
                EchoRouteRow(icon: "trash", title: "Delete Downloaded Media", subtitle: "Free space on this device only", action: coordinator.removeDownloads)
                Divider(); EchoRouteRow(icon: "clock.arrow.circlepath", title: "Delete Learning History", subtitle: "Keeps family lessons and practices", action: { confirmHistory = true })
                Divider(); EchoRouteRow(icon: "list.bullet.rectangle", title: "Delete My Practices", subtitle: "Remove practice media and shared practice records", action: { confirmPractices = true })
            }
            EchoCard { Label("Delete Account", systemImage: "exclamationmark.triangle.fill").font(EchoTheme.title(25)).foregroundStyle(.red); Text("Review what must be transferred and what will be removed."); Button("Review Account Deletion") { coordinator.show(.accountDeletion) }.buttonStyle(EchoSecondaryButtonStyle()) }
            EchoStatusNote(icon: "shield.lefthalf.filled", text: "Destructive actions always explain their exact local or account scope first.", color: EchoTheme.secondaryInk)
        }.confirmationDialog("Delete private learning history?", isPresented: $confirmHistory, titleVisibility: .visible) { Button("Delete Learning History", role: .destructive) { coordinator.deleteLearningHistory() }; Button("Cancel", role: .cancel) {} } message: { Text("Completed steps, progress, and questions are removed. Shared family lessons and practices stay.") }
        .confirmationDialog("Delete saved practices?", isPresented: $confirmPractices, titleVisibility: .visible) {
            Button("Delete My Practices", role: .destructive, action: coordinator.deletePractices)
            Button("Cancel", role: .cancel) {}
        } message: { Text("Practice attachments and their local family activity are removed. Source lessons and learning progress remain.") }
    }
}

struct AccountDeletionView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var confirmation = ""
    @State private var status: String?
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Manage My Data", title: "Before you delete your account.", onBack: { coordinator.show(.manageData) })
            Text("No online account is connected. You can permanently remove all EchoSkill data saved on this device.").font(.headline).foregroundStyle(EchoTheme.secondaryInk)
            EchoCard {
                Text("What needs attention").font(EchoTheme.title(25))
                Label("Your practices can be deleted", systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
                Label("Your learning history can be deleted", systemImage: "checkmark.circle.fill").foregroundStyle(EchoTheme.sage)
                Text("Export important content before continuing. This local removal has no recovery period.").font(.subheadline)
            }
            EchoCard { Text("What will be removed").font(EchoTheme.title(24)); Text("• Profile and settings\n• Personal progress and questions\n• Practice media and comments\n• Private lesson drafts") }
            EchoCard { Text("What stays outside EchoSkill").font(EchoTheme.title(24)); Text("Originals in Photos and exports you already saved elsewhere are not removed.") }
            Text("Type DELETE to continue").font(.headline)
            TextField("DELETE", text: $confirmation).textFieldStyle(.roundedBorder).textInputAutocapitalization(.characters).accessibilityLabel("Type DELETE to continue")
            Button("Delete All Local Data", role: .destructive) { coordinator.deleteLocalData(confirmation: confirmation) }.buttonStyle(EchoPrimaryButtonStyle()).disabled(confirmation != "DELETE")
            Button("Delete My Account", role: .destructive) {}.disabled(true)
            Text("Online account deletion becomes available when an account service is connected.").font(.footnote)
            Button("Keep My Account") { coordinator.show(.manageData) }.buttonStyle(EchoSecondaryButtonStyle())
            if let status { Text(status).font(.footnote).foregroundStyle(EchoTheme.terracotta) }
        }
    }
}

struct HelpSupportView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @State private var query = ""
    @State private var selectedTopic: String?
    @State private var showArticle = false
    private let topics = ["Create your first family lesson", "Fix a transcript or step", "Invite and manage family", "Understand privacy and AI", "Upload or processing problem", "iCloud isn’t syncing", "Camera or microphone access", "Restore a deleted lesson"]
    var visibleTopics: [String] { query.isEmpty ? topics : topics.filter { $0.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        EchoScreen {
            FamilyPageHeader(backTitle: "Settings", title: "How can we help?", onBack: { coordinator.show(.settings) })
            TextField("Search EchoSkill help", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Search EchoSkill help")
            EchoCard { HStack { VStack(alignment: .leading) { Text("Your memories matter").font(EchoTheme.title(27)); Text("Find help with recording, learning, privacy, or keeping your family library safe.") }; Image("FamilyFishing").resizable().scaledToFill().frame(width: 115, height: 110).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel("A family member teaching a child to fish") } }
            EchoEyebrow(text: query.isEmpty ? "Popular help & troubleshooting" : "Search results")
            EchoCard { ForEach(Array(visibleTopics.enumerated()), id: \.offset) { index, topic in if index > 0 { Divider() }; EchoRouteRow(icon: index.isMultiple(of: 2) ? "book" : "lock.shield", title: topic, tint: index.isMultiple(of: 2) ? EchoTheme.terracotta : EchoTheme.sage) { selectedTopic = topic; showArticle = true } } }
            if visibleTopics.isEmpty { Text("No matching articles. Try recording, privacy, or family.").foregroundStyle(EchoTheme.secondaryInk) }
            EchoEyebrow(text: "Contact")
            EchoCard { EchoRouteRow(icon: "message", title: "Message Support", subtitle: "Support service not connected in local V1", action: { coordinator.notice = "Support messaging will be connected before release." }); Divider(); EchoRouteRow(icon: "waveform.path.ecg", title: "Send Diagnostics", subtitle: "Review before sharing", tint: EchoTheme.sage, action: { coordinator.notice = "No diagnostics were sent. A review-and-consent flow is required first." }) }
            Button("Privacy Summary") { selectedTopic = "Understand privacy and AI"; showArticle = true }.frame(minHeight: 44)
            Text("EchoSkill \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))").font(.caption).frame(maxWidth: .infinity).foregroundStyle(EchoTheme.secondaryInk)
        }
        .sheet(isPresented: $showArticle) {
            NavigationStack {
                ScrollView { Text(article(selectedTopic ?? "")).font(.body).padding(24).frame(maxWidth: .infinity, alignment: .leading) }
                    .navigationTitle(selectedTopic ?? "Help").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showArticle = false } } }
            }
        }
    }
    private func article(_ title: String) -> String {
        switch title {
        case "Create your first family lesson": return "Open Capture and record or import a video up to 10 minutes. Add a title, maker and spoken language. Write or review the transcript, materials and steps, then preview and publish. Your lesson is saved on this device."
        case "Fix a transcript or step": return "In Capture, choose Continue Draft. Use Edit Transcript to preserve the maker’s words. In Steps Editor, edit the title, instructions and time range, then preview before approving. Original video is kept separately from your text edits."
        case "Invite and manage family": return "Open Family → Members to manage local member records and permissions. Pending invitations use one of five slots. Invitation delivery and cross-device access are not connected in this local build."
        case "Understand privacy and AI": return "Your local videos, reviewed text, profile and progress remain in the app’s private storage. There is no advertising, tracking SDK, remote AI or cloud sync in this build. Practice is private until you choose Share with Family. Export files can contain personal content; save them only where you trust. Manage My Data lets you export or clear your learning history."
        case "Upload or processing problem": return "Your source is saved locally before review. Automatic AI processing is not connected. Add transcript text and steps manually. If a video cannot import, check that it plays in Photos, lasts no more than 10 minutes and is smaller than 200 MB."
        case "iCloud isn’t syncing": return "iCloud and Family Sync are not connected in this build. Content stays on this device. Export important information before deleting the app or changing devices."
        case "Camera or microphone access": return "Allow Camera and Microphone in iOS Settings to record with sound. The simulator has no usable camera; import a video or try the clearly labeled example workflow instead. Importing through the system picker does not require full photo-library access."
        default: return "Permanent deletion cannot be reversed in this local build. Export important content before removing it. Never delete an original recording until you have verified another copy."
        }
    }
}
