import SwiftUI

struct presentPrivacyAndTerms: View {
    let onExternalURL: (URL) -> Void
    let onRefresh: () -> Void
    @ObservedObject private var handler = LegalConsentHandler.shared

    var body: some View {
        CompatibleNavigation {
            ZStack {
                ForEach(handler.pages.dropFirst()) { page in
                    LegalConsentPageView(page: page, onExternalURL: onExternalURL, onRefresh: onRefresh,
                                         fillsContainer: false)
                        .opacity(handler.pages.last?.id == page.id ? 1 : 0)
                        .allowsHitTesting(handler.pages.last?.id == page.id)
                        .accessibilityHidden(handler.pages.last?.id != page.id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(EchoTheme.ivory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { handler.legalConsent12() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .tint(EchoTheme.ink)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("activity-checkout-close")
                }
            }
            .compatibleNavigationBarBackground(EchoTheme.ivory)
        }
        .statusBarHidden(true)
        .alert("Unable to open link", isPresented: Binding(
            get: { handler.notice != nil },
            set: { if !$0 { handler.notice = nil } }
        )) {
            Button("OK", role: .cancel) { handler.notice = nil }
        } message: { Text(handler.notice ?? "") }
    }
}
