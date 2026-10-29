import SwiftUI

enum EchoTheme {
    static let ivory = Color(hex: 0xFBF8F2)
    static let paper = Color(hex: 0xFFFEFB)
    static let ink = Color(hex: 0x1F1B18)
    static let secondaryInk = Color(hex: 0x67625E)
    static let terracotta = Color(hex: 0xC85230)
    static let terracottaLight = Color(hex: 0xE9784E)
    static let terracottaSoft = Color(hex: 0xF7E2DA)
    static let sage = Color(hex: 0x5F8768)
    static let sageSoft = Color(hex: 0xE6EDE2)
    static let line = Color(hex: 0xDED7CE)

    static func title(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static let eyebrow = Font.system(.caption, design: .rounded, weight: .bold)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct EchoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background {
                LinearGradient(
                    colors: [EchoTheme.terracottaLight, EchoTheme.terracotta],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.8 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: EchoTheme.terracotta.opacity(0.13), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct EchoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(EchoTheme.terracotta)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(EchoTheme.paper.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(EchoTheme.terracotta, lineWidth: 1.4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EchoScreen<Content: View>: View {
    let showsBackButton: Bool
    let onBack: () -> Void
    @ViewBuilder let content: Content

    init(
        showsBackButton: Bool = false,
        onBack: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.showsBackButton = showsBackButton
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        ZStack {
            EchoTheme.ivory.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showsBackButton {
                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.left")
                                .font(.headline)
                                .frame(minHeight: 44)
                        }
                        .accessibilityLabel("Back")
                    }

                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(EchoTheme.terracotta)
    }
}

struct EchoBrand: View {
    var body: some View {
        Text("EchoSkill")
            .font(.system(size: 32, weight: .bold, design: .serif))
            .foregroundStyle(EchoTheme.terracotta)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }
}

struct EchoEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(EchoTheme.eyebrow)
            .tracking(2.1)
            .foregroundStyle(Color(hex: 0x846A5C))
    }
}

struct EchoPageDots: View {
    let selected: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == selected ? EchoTheme.terracotta : EchoTheme.line)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding page \(selected + 1) of 3")
    }
}

struct EchoFeatureIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(color)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
