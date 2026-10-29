import PhotosUI
import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var coordinator: FamilyProfileCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selection: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var removesPhoto = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(coordinator: FamilyProfileCoordinator) {
        self.coordinator = coordinator
        _name = State(initialValue: coordinator.currentUser?.name ?? "")
    }

    private var previewMember: FamilyMember? {
        guard var member = coordinator.currentUser else { return nil }
        if removesPhoto { member.avatarFilename = nil }
        return member
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 14) {
                        PhotosPicker(selection: $selection, matching: .images) {
                            VStack(spacing: 12) {
                                Group {
                                    if let photoData, let image = UIImage(data: photoData) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                            .frame(width: 130, height: 130).clipShape(Circle())
                                    } else if let member = previewMember {
                                        FamilyMemberAvatar(member: member, size: 130)
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(.white).padding(9)
                                        .background(EchoTheme.terracotta).clipShape(Circle())
                                }
                                Text(isLoading ? "Loading Photo…" : "Choose Photo").font(.headline)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose Profile Photo")
                        .disabled(isLoading)
                        if photoData != nil || (previewMember?.avatarFilename != nil) {
                            Button("Use Default Photo") {
                                photoData = nil
                                removesPhoto = true
                                selection = nil
                                errorMessage = nil
                            }.font(.subheadline)
                        }
                        Text("Choose a photo from your library.")
                            .font(.footnote).foregroundStyle(EchoTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name").font(.headline)
                        TextField("Your name", text: $name)
                            .textContentType(.name).textInputAutocapitalization(.words)
                            .autocorrectionDisabled().accessibilityLabel("Profile name")
                            .padding(14).background(EchoTheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay { RoundedRectangle(cornerRadius: 14).stroke(EchoTheme.line) }
                        Text("\(name.count)/80 characters").font(.caption)
                            .foregroundStyle(name.count > 80 ? EchoTheme.terracotta : EchoTheme.secondaryInk)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(EchoTheme.terracotta)
                            .accessibilityIdentifier("Profile edit error")
                    }
                    EchoStatusNote(icon: "iphone", text: "Your name and photo are saved on this iPhone. Changes are applied only when you tap Save.")
                }
                .padding(22)
            }
            .background(EchoTheme.ivory)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if coordinator.updateProfile(name: name, avatarData: photoData, removeAvatar: removesPhoto) {
                            dismiss()
                        } else { errorMessage = coordinator.profileEditError }
                    }.disabled(isLoading)
                }
            }
            .tint(EchoTheme.terracotta)
            .task(id: selection) {
                guard let selection else { return }
                isLoading = true
                errorMessage = nil
                defer { isLoading = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else { throw ProfilePhotoError.invalidImage }
                    try Task.checkCancellation()
                    let jpeg = try ProfilePhotoProcessor.jpeg(from: data)
                    try Task.checkCancellation()
                    photoData = jpeg
                    removesPhoto = false
                } catch is CancellationError {
                    // Dismissing the editor/picker never changes the stored profile.
                } catch {
                    errorMessage = (error as? ProfilePhotoError)?.errorDescription ?? "This photo could not be opened. Choose another image."
                }
            }
        }
    }
}
