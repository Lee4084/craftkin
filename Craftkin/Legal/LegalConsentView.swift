import SwiftUI

struct LegalConsentView: View {
    let onAgree: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var legalConsentHandler = LegalConsentHandler.shared
    @State private var loadState: LegalPageLoadState = .loading
    @State private var reloadID = UUID()
    @State private var isShowingActivity = false
    @State private var refreshActivity = false
    @State private var externalPage: ExternalLegalPage?

    init(onAgree: @escaping () -> Void) {
        self.onAgree = onAgree
    }

    private var pageURL: URL {
        let entry = LegalConsentBridge.acceptanceURL(for: LegalDocument.startupURL)
        if refreshActivity {
            var components = URLComponents(url: entry, resolvingAgainstBaseURL: false)!
            components.queryItems?.append(URLQueryItem(name: "refresh", value: "1"))
            return components.url!
        }
        return entry
    }

    var body: some View {
        ZStack {
            LegalConsentWebView(url: pageURL, state: $loadState,
                                onAgree: onAgree, onExternalURL: showExternalURL,
                                onActivityChanged: { isShowingActivity = $0 },
                                onCloseActivity: { restart() })
                .id(reloadID)
                .opacity(loadState != .ready || !legalConsentHandler.pages.isEmpty ? 0 : 1)
                .allowsHitTesting(loadState == .ready && legalConsentHandler.pages.isEmpty)
                .accessibilityHidden(loadState != .ready || !legalConsentHandler.pages.isEmpty)
            if loadState == .failed {
                errorView
            } else if loadState == .loading {
                VStack(spacing: 16) {
                    ProgressView()
                        .accessibilityLabel("Loading")
                        .tint(EchoTheme.terracotta)
                }
                .padding(24)
            }
            ForEach(legalConsentHandler.pages.prefix(1)) { page in
                LegalConsentPageView(page: page, onExternalURL: showExternalURL,
                                     onRefresh: { restart(refresh: true) })
                    .allowsHitTesting(legalConsentHandler.pages.last?.id == page.id)
                    .accessibilityHidden(legalConsentHandler.pages.last?.id != page.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container)
        .foregroundStyle(EchoTheme.ink)
        .background(EchoTheme.ivory.ignoresSafeArea())
        .statusBarHidden(true)
        .alert("Unable to complete action", isPresented: Binding(
            get: { legalConsentHandler.notice != nil && legalConsentHandler.pages.count <= 1 },
            set: { if !$0 && legalConsentHandler.pages.count <= 1 { legalConsentHandler.notice = nil } }
        )) {
            Button("OK", role: .cancel) { legalConsentHandler.notice = nil }
        } message: { Text(legalConsentHandler.notice ?? "") }
        .onChange(of: scenePhase) { value in legalConsentHandler.legalConsent5(value == .active) }
        .onChange(of: externalPage?.id) { value in legalConsentHandler.legalConsent5(value == nil && scenePhase == .active) }
        .onDisappear {
            if externalPage == nil && legalConsentHandler.pages.count <= 1 { legalConsentHandler.legalConsent4() }
        }
        .sheet(isPresented: Binding(
            get: { legalConsentHandler.pages.count > 1 },
            set: { if !$0 { legalConsentHandler.legalConsent12() } }
        ), onDismiss: {
            legalConsentHandler.legalConsent12()
        }) {
            presentPrivacyAndTerms(onExternalURL: showExternalURL,
                                    onRefresh: { restart(refresh: true) })
                .compatibleSheet([.large], showsGrabber: false)
                .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $externalPage) {
            LegalExternalBrowser(url: $0.url).ignoresSafeArea()
        }
        .accessibilityIdentifier("legal-consent-screen")
    }

    private var errorView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EchoEyebrow(text: "Before you begin")
                Text(isShowingActivity ? "Couldn’t load the activity" : "Couldn’t load the agreement").font(.title2.bold())
                Text("Check your internet connection and try again.")
                    .foregroundStyle(EchoTheme.secondaryInk)
                Button("Retry") {
                    restart(refresh: refreshActivity)
                }
                .accessibilityIdentifier("legal-retry")
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EchoTheme.ivory)
        .accessibilityIdentifier("legal-load-error")
    }

    private func restart(refresh: Bool = false) {
        legalConsentHandler.legalConsent4()
        refreshActivity = refresh
        isShowingActivity = false
        loadState = .loading
        reloadID = UUID()
    }

    private func showExternalURL(_ url: URL) {
        if url.scheme == "mailto" { openURL(url) }
        else if ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            externalPage = ExternalLegalPage(url: url)
        }
    }
}

private struct ExternalLegalPage: Identifiable {
    let url: URL
    var id: URL { url }
}
