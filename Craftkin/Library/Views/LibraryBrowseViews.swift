import SwiftUI

struct AllSkillsView: View {
    @ObservedObject var coordinator: LibraryCoordinator
    @State private var showsFilters = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LibraryBackButton(title: "Library", action: coordinator.goBack)
                Text("All Skills").font(EchoTheme.title(42)).accessibilityAddTraits(.isHeader)

                Button(action: coordinator.beginSearch) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search skills, people, or tools")
                        Spacer()
                    }
                    .font(.headline).foregroundStyle(EchoTheme.secondaryInk)
                    .padding(16).background(EchoTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search Library")

                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            LibraryFilterChip(title: "All \(coordinator.skills.count)", selected: coordinator.filter.progress == nil) {
                                coordinator.filter.progress = nil
                            }
                            LibraryFilterChip(title: "In Progress", selected: coordinator.filter.progress == .inProgress) {
                                coordinator.filter.progress = .inProgress
                            }
                            LibraryFilterChip(title: "Completed", selected: coordinator.filter.progress == .completed) {
                                coordinator.filter.progress = .completed
                            }
                            Menu {
                                ForEach(LibrarySort.allCases, id: \.self) { sort in
                                    Button(sort.title) { coordinator.filter.sort = sort }
                                }
                            } label: {
                                Label(coordinator.filter.sort.title, systemImage: "chevron.down")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.ink)
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(EchoTheme.paper).clipShape(Capsule())
                            }
                        }
                    }
                    Button { showsFilters = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44).background(EchoTheme.terracottaSoft).clipShape(Circle())
                    }
                    .accessibilityLabel("Filter Library")
                }

                if coordinator.visibleSkills.isEmpty {
                    ContentUnavailableView(
                        "No skills match these filters",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Clear filters to see your whole Family Space.")
                    )
                    Button("Clear Filters", action: coordinator.clearFilters)
                        .buttonStyle(EchoSecondaryButtonStyle())
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(coordinator.visibleSkills) { skill in
                            SkillGridCard(skill: skill) { coordinator.showSkill(skill.id) }
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsFilters) {
            LibraryFilterSheet(coordinator: coordinator, isPresented: $showsFilters)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct LibrarySearchView: View {
    @ObservedObject var coordinator: LibraryCoordinator
    @State private var showsFilters = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EchoEyebrow(text: "Library")
                Text("Search Library").font(EchoTheme.title(42)).accessibilityAddTraits(.isHeader)

                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(EchoTheme.secondaryInk)
                        TextField("Search skills, people, or tools", text: $coordinator.searchText)
                            .focused($searchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Search skills, people, or tools")
                        if !coordinator.searchText.isEmpty {
                            Button {
                                coordinator.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Clear search text")
                        }
                    }
                    .padding(14).background(EchoTheme.paper).clipShape(RoundedRectangle(cornerRadius: 16))
                    Button("Cancel", action: coordinator.clearSearch).font(.headline)
                }

                if coordinator.filter.activeCount > 0 {
                    HStack {
                        Text("\(coordinator.filter.activeCount) active filters")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.terracotta)
                        Spacer()
                        Button("Edit Filters") { showsFilters = true }
                    }
                } else {
                    Button { showsFilters = true } label: {
                        Label("Filter Library", systemImage: "slider.horizontal.3")
                    }
                }

                if coordinator.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SearchSuggestions(coordinator: coordinator)
                } else if coordinator.searchResults.isEmpty {
                    SearchNoResultsView(coordinator: coordinator)
                } else {
                    Text("\(coordinator.searchResults.count) results")
                        .font(.title3.weight(.semibold))
                    ForEach(coordinator.searchResults) { skill in
                        SearchResultCard(skill: skill, query: coordinator.searchText) {
                            coordinator.showSkill(skill.id)
                        }
                    }
                }

                Label("Search only looks inside your Family Space.", systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(EchoTheme.secondaryInk)
                    .frame(maxWidth: .infinity).padding(.top, 12)
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { searchFocused = true }
        .sheet(isPresented: $showsFilters) {
            LibraryFilterSheet(coordinator: coordinator, isPresented: $showsFilters)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }
}

private struct SearchSuggestions: View {
    @ObservedObject var coordinator: LibraryCoordinator
    private let suggestions = ["recipes", "repairs", "Grandma", "gardening"]

    var body: some View {
        Text("Try searching for").font(EchoTheme.title(29))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button { coordinator.searchText = suggestion } label: {
                    Label(suggestion, systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.sage)
                        .frame(maxWidth: .infinity, minHeight: 44).background(EchoTheme.sageSoft).clipShape(Capsule())
                }
            }
        }
    }
}

private struct SearchNoResultsView: View {
    @ObservedObject var coordinator: LibraryCoordinator

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                Image("FamilyPiano").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel("Piano teaching inspiration for a future family skill")
            }.frame(height: 235)
            Text("No family skills found.").font(EchoTheme.title(34)).multilineTextAlignment(.center)
            Text("Nothing in your Family Space matches “\(coordinator.searchText)” yet.")
                .font(.title3).foregroundStyle(EchoTheme.secondaryInk).multilineTextAlignment(.center)
            Button("Record This Skill") { coordinator.explainLaterPhase("Record This Skill") }
                .buttonStyle(EchoPrimaryButtonStyle())
            Button("Clear Search", action: coordinator.clearSearch)
                .buttonStyle(EchoSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SearchResultCard: View {
    let skill: SkillLesson
    let query: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(skill.coverImageName).resizable().scaledToFill().frame(width: 112, height: 118).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 7) {
                    Text(skill.title).font(.system(.title3, design: .serif, weight: .bold)).lineLimit(2)
                    Text("\(skill.maker.relation) · \(skill.stepCount) steps")
                        .font(.subheadline).foregroundStyle(EchoTheme.sage)
                    Text(skill.transcript).font(.subheadline).foregroundStyle(EchoTheme.secondaryInk).lineLimit(2)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").foregroundStyle(EchoTheme.secondaryInk)
            }
            .foregroundStyle(EchoTheme.ink).padding(10).background(EchoTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain).accessibilityLabel(skill.title)
    }
}

private struct LibraryFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(selected ? .white : EchoTheme.ink)
            .padding(.horizontal, 15).frame(minHeight: 44)
            .background(selected ? EchoTheme.terracotta : EchoTheme.paper).clipShape(Capsule())
    }
}

struct LibraryFilterSheet: View {
    @ObservedObject var coordinator: LibraryCoordinator
    @Binding var isPresented: Bool
    @State private var draft: LibraryFilter

    init(coordinator: LibraryCoordinator, isPresented: Binding<Bool>) {
        self.coordinator = coordinator
        _isPresented = isPresented
        _draft = State(initialValue: coordinator.filter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Filter Library").font(EchoTheme.title(38))
                    Spacer()
                    Button("Reset") { draft = coordinator.filter }
                }

                Text("Family member").font(EchoTheme.title(25))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(coordinator.makers) { maker in
                            Button {
                                if draft.makerIDs.contains(maker.id) { draft.makerIDs.remove(maker.id) }
                                else { draft.makerIDs.insert(maker.id) }
                            } label: {
                                VStack {
                                    MakerAvatar(maker: maker, size: 66)
                                        .overlay { Circle().stroke(draft.makerIDs.contains(maker.id) ? EchoTheme.terracotta : EchoTheme.line, lineWidth: 3) }
                                    Text(maker.relation).font(.caption).foregroundStyle(EchoTheme.ink)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }

                Text("Category").font(EchoTheme.title(25))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(coordinator.categories, id: \.self) { category in
                            LibraryFilterChip(title: category, selected: draft.categories.contains(category)) {
                                if draft.categories.contains(category) { draft.categories.remove(category) }
                                else { draft.categories.insert(category) }
                            }
                        }
                    }
                }

                Text("Progress").font(EchoTheme.title(25))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        LibraryFilterChip(title: "Any", selected: draft.progress == nil) { draft.progress = nil }
                        ForEach([SkillProgress.new, .inProgress, .completed], id: \.self) { progress in
                            LibraryFilterChip(title: progress.filterTitle, selected: draft.progress == progress) { draft.progress = progress }
                        }
                    }
                }

                Text("Sort by").font(EchoTheme.title(25))
                ForEach(LibrarySort.allCases, id: \.self) { sort in
                    Button { draft.sort = sort } label: {
                        HStack {
                            Image(systemName: draft.sort == sort ? "largecircle.fill.circle" : "circle")
                            Text(sort.title)
                            Spacer()
                        }
                        .font(.headline).foregroundStyle(EchoTheme.ink).frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }

            }
            .padding(22)
        }
        .background(EchoTheme.ivory)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button("Show \(LibraryQueryEngine.apply(draft, to: coordinator.skills).count) Results") {
                    coordinator.apply(draft); isPresented = false
                }.buttonStyle(EchoPrimaryButtonStyle())
                Button("Clear Filters") {
                    draft = LibraryFilter(); coordinator.clearFilters(); isPresented = false
                }.frame(maxWidth: .infinity, minHeight: 40)
            }
            .padding(.horizontal, 22).padding(.top, 8)
            .background(EchoTheme.ivory)
        }
    }
}

private extension SkillProgress {
    var filterTitle: String {
        switch self {
        case .new: "New"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        case .saved: "Saved"
        }
    }
}
