import SwiftUI

struct LegalConsentPageView: View {
    let page: LegalConsentPage
    let onExternalURL: (URL) -> Void
    let onRefresh: () -> Void
    var fillsContainer = true
    @State private var state: LegalPageLoadState = .loading
    @State private var reloadID = UUID()
    var body: some View {
        ZStack {
            LegalConsentWebView(url: page.url, state: $state,
                                onAgree: {}, onExternalURL: onExternalURL,
                                onActivityChanged: { _ in }, legalConsentPage: page)
                .id(reloadID)
                .opacity(state == .failed ? 0 : 1)
                .allowsHitTesting(state == .ready)
                .accessibilityHidden(state != .ready)
            if state == .loading {
                ProgressView()
                    .accessibilityLabel("Loading")
                    .tint(EchoTheme.terracotta)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EchoTheme.ivory)
            } else if state == .failed {
                VStack(spacing: 20) {
                    Text("Couldn’t load this page").font(.title2.bold())
                    Button("Retry") { state = .loading; reloadID = UUID() }
                    Button("Refresh activities", action: onRefresh)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(EchoTheme.ink)
        .background(EchoTheme.ivory)
        .ignoresSafeArea(.container, edges: fillsContainer ? .all : [])
    }
}
