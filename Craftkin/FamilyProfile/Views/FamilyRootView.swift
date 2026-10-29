import SwiftUI

struct FamilyRootView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    var onOpenProfile: (() -> Void)?

    var body: some View {
        Group {
            switch coordinator.route {
            case .familyOverview: FamilyOverviewView(coordinator: coordinator, onOpenProfile: onOpenProfile)
            case .members: MembersView(coordinator: coordinator)
            case .inviteMember: InviteMemberView(coordinator: coordinator)
            case let .memberPermissions(id): MemberPermissionsView(memberID: id, coordinator: coordinator)
            case .familyActivity: FamilyActivityView(coordinator: coordinator)
            case .makerArchive: MakerArchiveView(coordinator: coordinator)
            default: ProfileRootView(coordinator: coordinator)
            }
        }
        .alert("EchoSkill", isPresented: Binding(get: { coordinator.notice != nil }, set: { if !$0 { coordinator.notice = nil } })) {
            Button("OK", role: .cancel) { coordinator.notice = nil }
        } message: { Text(coordinator.notice ?? "") }
    }
}

struct ProfileRootView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    var body: some View {
        switch coordinator.route {
        case .profile: MyProfileView(coordinator: coordinator)
        case .settings: SettingsView(coordinator: coordinator)
        case .storage: StorageView(coordinator: coordinator)
        case .notifications: NotificationsView(coordinator: coordinator)
        case .privacy: PrivacyPermissionsView(coordinator: coordinator)
        case .manageData: ManageDataView(coordinator: coordinator)
        case .accountDeletion: AccountDeletionView(coordinator: coordinator)
        case .help: HelpSupportView(coordinator: coordinator)
        default: FamilyOverviewView(coordinator: coordinator)
        }
    }
}
