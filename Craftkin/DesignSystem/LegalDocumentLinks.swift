import SwiftUI

struct LegalDocumentLinks: View {
    var body: some View {
        Group {
            if let url = URL(string: IntegrationConstants.Legal.terms) {
                Link(destination: url) {
                    Text(IntegrationConstants.Text.terms).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier(IntegrationConstants.Text.termsID)
            }
            if let url = URL(string: IntegrationConstants.Legal.privacy) {
                Link(destination: url) {
                    Text(IntegrationConstants.Text.privacy).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier(IntegrationConstants.Text.privacyID)
            }
        }
        .tint(EchoTheme.sage)
    }
}
