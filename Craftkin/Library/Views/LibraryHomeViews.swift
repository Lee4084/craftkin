import SwiftUI

struct LibraryHomeView: View {
    @ObservedObject var coordinator: LibraryCoordinator
    @ObservedObject var profileCoordinator: FamilyProfileCoordinator
    var onCapture: () -> Void = {}
    var onOpenProfile: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LibraryHeader(
                    title: coordinator.skills.isEmpty ? "Every skill starts\nwith a story." : "Keep their\nknow-how alive.",
                    status: "Saved on this device",
                    user: profileCoordinator.currentUser,
                    onOpenProfile: onOpenProfile
                )

                if coordinator.skills.isEmpty {
                    EmptyLibraryContent(coordinator: coordinator, onCapture: onCapture)
                } else {
                    PopulatedLibraryContent(coordinator: coordinator, onCapture: onCapture)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct LibraryHeader: View {
    let title: String
    let status: String
    let user: FamilyMember?
    let onOpenProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 7) {
                    EchoEyebrow(text: "Family Skill Library")
                    Text(title)
                        .font(EchoTheme.title(40))
                        .foregroundStyle(EchoTheme.ink)
                        .lineSpacing(-2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
                        .accessibilityAddTraits(.isHeader)
                }
                Button(action: onOpenProfile) {
                    Group {
                        if let user { FamilyMemberAvatar(member: user, size: 50) }
                        else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(EchoTheme.terracotta) }
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Profile")
                .accessibilityValue("\(user?.name ?? "Your profile"), \(user?.avatarFilename == nil ? "Default photo" : "Custom photo")")
            }
            Label(status, systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(EchoTheme.sage)
        }
    }
}

private struct PopulatedLibraryContent: View {
    @ObservedObject var coordinator: LibraryCoordinator
    let onCapture: () -> Void

    var body: some View {
        if let featured = coordinator.featuredSkill {
            Button { coordinator.showSkill(featured.id) } label: {
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { geometry in
                        Image(featured.coverImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .frame(height: 265)
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONTINUE LEARNING").font(.caption.weight(.bold)).tracking(1.2)
                        Text(featured.title).font(.system(.title, design: .serif, weight: .bold))
                        Text("\(featured.completedSteps) of \(featured.stepCount) steps").font(.headline)
                        ProgressView(value: Double(featured.completedSteps), total: Double(featured.stepCount))
                            .tint(EchoTheme.terracottaLight)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(featured.title), continue learning")
        }

        Button(action: onCapture) {
            HStack(spacing: 15) {
                Image(systemName: "video.badge.plus")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 56, height: 56).background(EchoTheme.terracotta).clipShape(Circle())
                VStack(alignment: .leading) {
                    Text("Record a Skill").font(.system(.title3, design: .serif, weight: .bold))
                    Text("Film it. Turn it into a lesson.").foregroundStyle(EchoTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(EchoTheme.ink)
            .padding(16).background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)

        HStack {
            Text("Recent Skills").font(EchoTheme.title(29))
            Spacer()
            Button("See All", action: coordinator.showAllSkills).font(.headline)
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(coordinator.visibleSkills.prefix(4)) { skill in
                SkillGridCard(skill: skill) { coordinator.showSkill(skill.id) }
            }
        }

        Text("Family Makers").font(EchoTheme.title(29))
        HStack(alignment: .top) {
            ForEach(coordinator.makers.prefix(3)) { maker in
                Button { coordinator.showMaker(maker.id) } label: {
                    VStack(spacing: 5) {
                        MakerAvatar(maker: maker, size: 72)
                        Text(maker.relation).font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.ink)
                        Text("\(coordinator.skills(for: maker).count) skills").font(.caption).foregroundStyle(EchoTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(maker.relation) profile")
            }
        }
    }
}

private struct EmptyLibraryContent: View {
    @ObservedObject var coordinator: LibraryCoordinator
    let onCapture: () -> Void

    var body: some View {
        GeometryReader { geometry in
            Image("FamilyCooking")
                .resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Family members preparing a meal together, an idea for a first skill")
        }
        .frame(height: 260)

        Text("Record a family member sharing something only they know.")
            .font(.system(.title2, design: .serif, weight: .bold))
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)

        Button("Record First Skill", action: onCapture)
            .buttonStyle(EchoPrimaryButtonStyle())
        Button("Import a Video", action: onCapture)
            .buttonStyle(EchoSecondaryButtonStyle())

        Text("Ideas to begin").font(EchoTheme.title(29))
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
            IdeaCard(title: "Family Recipes", icon: "frying.pan.fill", color: EchoTheme.terracotta)
            IdeaCard(title: "Home Repairs", icon: "hammer.fill", color: EchoTheme.sage)
            IdeaCard(title: "Handmade Crafts", icon: "scissors", color: .orange)
            IdeaCard(title: "Traditions", icon: "house.fill", color: .blue.opacity(0.7))
        }

        Label("Start with five minutes. You can refine the lesson before sharing.", systemImage: "lightbulb")
            .font(.subheadline).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.sageSoft).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct IdeaCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(.white)
                .frame(width: 54, height: 54).background(color).clipShape(Circle())
            Text(title).font(.system(.headline, design: .serif)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 128).background(EchoTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct SkillGridCard: View {
    let skill: SkillLesson
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(skill.coverImageName).resizable().scaledToFill().frame(height: 112).clipped()
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .lineLimit(2, reservesSpace: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(skill.maker.relation) · \(skill.stepCount) steps")
                        .font(.caption).foregroundStyle(EchoTheme.secondaryInk)
                }
                .padding(10)
            }
            .foregroundStyle(EchoTheme.ink).background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(EchoTheme.line.opacity(0.55)) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(skill.title)
    }
}
