import SwiftUI
import UIKit

struct WebIntegrationView: View {
    @ObservedObject var coordinator: WebIntegrationCoordinator
    let onClose: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if !hasFailed {
                ProgressView(IntegrationConstants.Text.loading)
            } else {
                Image(systemName: "globe").font(.system(size: 48)).foregroundStyle(EchoTheme.terracotta)
                Text(message).multilineTextAlignment(.center)
                    .accessibilityIdentifier(IntegrationConstants.Text.unavailableID)
                #if DEBUG
                if let diagnostic = coordinator.diagnostic {
                    Text(diagnostic.reference)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier(IntegrationConstants.Diagnostic.identifier)
                    if let endpoints = diagnostic.endpoints {
                        Text(endpoints.description)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }
                }
                #endif
                if coordinator.state == .failed(.offline) {
                    Button(IntegrationConstants.Text.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(EchoSecondaryButtonStyle())
                }
                if canRetry {
                    Button(IntegrationConstants.Text.retry, action: onRetry).buttonStyle(EchoPrimaryButtonStyle())
                }
                Button(IntegrationConstants.Text.close, action: onClose)
                    .buttonStyle(EchoSecondaryButtonStyle())
                    .accessibilityIdentifier(IntegrationConstants.Text.closeID)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EchoTheme.ivory.ignoresSafeArea())
    }

    private var hasFailed: Bool {
        if case .failed = coordinator.state { return true }
        return false
    }

    private var canRetry: Bool {
        if case .failed(let error) = coordinator.state { return error != .unavailable && error != .invalidConfiguration }
        return false
    }
    private var message: String {
        switch coordinator.state {
        case .failed(.unavailable), .failed(.invalidConfiguration): return IntegrationConstants.Text.unavailable
        case .failed(.missingEntryMaterial): return IntegrationConstants.Text.missingMaterial
        case .failed(.offline): return IntegrationConstants.Text.offline
        case .failed(.servicesUnavailable): return IntegrationConstants.Text.missingServices
        default: return IntegrationConstants.Text.failed
        }
    }
}
