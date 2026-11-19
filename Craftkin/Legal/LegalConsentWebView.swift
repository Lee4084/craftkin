import SwiftUI
import WebKit
import SafariServices
import UIKit

enum LegalPageLoadState { case loading, ready, failed }

struct LegalConsentWebView: UIViewRepresentable {
    let url: URL
    @Binding var state: LegalPageLoadState
    let onAgree: () -> Void
    let onExternalURL: (URL) -> Void
    let onActivityChanged: (Bool) -> Void
    var legalConsentPage: LegalConsentPage? = nil
    var onCloseActivity: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        if legalConsentPage != nil {
            configuration.allowsInlineMediaPlayback = true
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        configuration.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page,
                                                                     name: LegalConsentBridge.name)
        configuration.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page,
                                                                     name: LegalConsentValues.privacyAndTerms)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(EchoTheme.ivory)
        webView.scrollView.backgroundColor = UIColor(EchoTheme.ivory)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = legalConsentPage?.allowsBackForward ?? true
        webView.accessibilityIdentifier = "legal-consent-webview"
        let policy: URLRequest.CachePolicy = legalConsentPage == nil ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        webView.load(legalConsentPage?.legalConsent2 ?? URLRequest(url: url, cachePolicy: policy, timeoutInterval: 30))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.owner = self
        if let legalConsentPage { webView.allowsBackForwardNavigationGestures = legalConsentPage.allowsBackForward }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: LegalConsentBridge.name,
                                                                                contentWorld: .page)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: LegalConsentValues.privacyAndTerms,
                                                                                contentWorld: .page)
        webView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply {
        var owner: LegalConsentWebView
        private var hasAccepted = false
        init(owner: LegalConsentWebView) { self.owner = owner }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                                   replyHandler: @escaping (Any?, String?) -> Void) {
            if message.name == LegalConsentValues.privacyAndTerms {
                guard owner.legalConsentPage == nil, message.frameInfo.isMainFrame,
                      let source = message.frameInfo.request.url,
                      LegalConsentBridge.canReceiveMessage(from: source),
                      ["start", "start.html"].contains(source.lastPathComponent),
                      let query = URLComponents(url: source, resolvingAgainstBaseURL: false)?.queryItems,
                      query.filter({ $0.name == "consent" }).map(\.value) == ["app"],
                      let body = message.body as? [String: String] else {
                    replyHandler(nil, "This page cannot request that navigation.")
                    return
                }
                if body["action"] == "legalConsent2" {
                    do {
                        let candidate = body["installation"].flatMap { $0.isEmpty ? nil : $0 }
                        let identity = try LegalConsentIdentityStore().resolve(migrating: candidate)
                        replyHandler(["installation": identity], nil)
                    } catch { replyHandler(nil, "The device identity is unavailable. Please retry.") }
                    return
                }
                guard body["action"] == "legalConsent1",
                      let raw = body["url"], let destination = URL(string: raw) else {
                    replyHandler(nil, "This page cannot request that navigation.")
                    return
                }
                let next = body["supportURL"].flatMap(URL.init(string:))
                guard let sourceView = message.webView else {
                    replyHandler(nil, "The page is no longer available.")
                    return
                }
                LegalConsentHandler.shared.legalConsent1(destination, next: next, source: sourceView,
                                                        onClose: owner.onCloseActivity)
                owner.onActivityChanged(true)
                replyHandler(["allowed": true, "opened": true], nil)
                return
            }
            guard owner.legalConsentPage == nil, !hasAccepted, message.name == LegalConsentBridge.name,
                  LegalConsentBridge.canAccept(message.body, from: message.frameInfo.request.url,
                                               isMainFrame: message.frameInfo.isMainFrame,
                                               hasLoaded: owner.state == .ready) else {
                replyHandler(nil, "The agreement is not ready for acceptance. Please try again.")
                return
            }
            hasAccepted = true
            replyHandler(["accepted": true], nil)
            owner.onAgree()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.scheme == LegalConsentValues.legalConsent1 {
                decisionHandler(.cancel)
                guard let page = owner.legalConsentPage,
                      let operation = LegalConsentValues.legalConsent6(url) else { return }
                LegalConsentHandler.shared.legalConsent2(operation, in: webView, page: page.id)
                return
            }
            if let page = owner.legalConsentPage {
                switch LegalConsentValues.legalConsent14(url, targetMainFrame: navigationAction.targetFrame?.isMainFrame) {
                case .legalConsent1: decisionHandler(.allow)
                case .legalConsent3:
                    decisionHandler(.cancel)
                    LegalConsentHandler.shared.legalConsent11(navigationAction.request, page: page.id)
                case .legalConsent4:
                    decisionHandler(.cancel)
                    LegalConsentHandler.shared.legalConsent2(.legalConsent2(url), in: webView, page: page.id)
                }
                return
            }
            switch LegalConsentValues.legalConsent14(url, targetMainFrame: navigationAction.targetFrame?.isMainFrame) {
            case .legalConsent1:
                decisionHandler(.allow)
            case .legalConsent3:
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
            case .legalConsent4:
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if owner.legalConsentPage != nil || !navigationResponse.isForMainFrame {
                decisionHandler(.allow)
                return
            }
            let response = navigationResponse.response
            let successful = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } == true
            guard successful else {
                owner.state = .failed
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            owner.state = .loading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            owner.state = .ready
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            failUnlessCancelled(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            failUnlessCancelled(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { owner.state = .failed }

        private func failUnlessCancelled(_ error: any Error) {
            let error = error as NSError
            if error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled { owner.state = .failed }
        }
    }
}

struct LegalExternalBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
