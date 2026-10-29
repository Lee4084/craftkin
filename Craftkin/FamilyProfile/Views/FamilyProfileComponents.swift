import SwiftUI

struct EchoCard<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(EchoTheme.line.opacity(0.55)) }
    }
}

struct EchoSectionTitle: View {
    let title: String
    var body: some View { Text(title).font(EchoTheme.title(27)).accessibilityAddTraits(.isHeader) }
}

struct EchoRouteRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = EchoTheme.terracotta
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(tint).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(EchoTheme.ink)
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(EchoTheme.secondaryInk) }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(EchoTheme.secondaryInk)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EchoStatusNote: View {
    let icon: String
    let text: String
    var color: Color = EchoTheme.sage
    var body: some View {
        Label(text, systemImage: icon)
            .font(.footnote).foregroundStyle(color)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct FamilyMemberAvatar: View {
    let member: FamilyMember
    var size: CGFloat = 58
    var body: some View {
        Group {
            if let url = LocalMediaStore().url(for: member.avatarFilename), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(RuntimePhotos.maker(member.imageName, relation: member.relation)).resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle()).accessibilityHidden(true)
    }
}

struct FamilyPageHeader: View {
    let backTitle: String
    let title: String
    let onBack: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LibraryBackButton(title: backTitle, action: onBack)
            Text(title).font(EchoTheme.title(42)).accessibilityAddTraits(.isHeader)
        }
    }
}
