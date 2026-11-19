import SwiftUI

struct LegalDocumentLinks: View {
    @State private var selected: LegalDocument?
    var body: some View {
        ForEach(LegalDocument.allCases) { document in
            Button { selected = document } label: {
                Text(document.title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier(document == .terms ? "legal-terms-link" : "legal-privacy-link")
        }
        .tint(EchoTheme.sage)
        .fullScreenCover(item: $selected) { LegalExternalBrowser(url: $0.url).ignoresSafeArea() }
    }
}
