import Combine
import UIKit
import WebKit

@MainActor
final class LegalConsentHandler: ObservableObject {
    static let shared = LegalConsentHandler()
    private init() {}

    @Published private(set) var pages: [LegalConsentPage] = []
    @Published var notice: String?
    private weak var source: WKWebView?
    private var rootURL: URL?
    private var nextURL: URL?
    private var onClose: (() -> Void)?
    private var idleValues: [UUID: Bool] = [:]
    private var previousIdle: Bool?
    private var isActive = true
    private var revision = 0
    private var legalConsent9 = false
    private var legalConsent10: (() -> Void)?

    func legalConsent1(_ url: URL, next: URL?, source: WKWebView, onClose: @escaping () -> Void) {
        legalConsent4()
        self.source = source
        self.rootURL = url
        self.nextURL = next
        self.onClose = onClose
        previousIdle = UIApplication.shared.isIdleTimerDisabled
        pages = [LegalConsentPage(url: url)]
    }

    func legalConsent2(_ operation: LegalConsentOperation, in webView: WKWebView, page: UUID) {
        guard pages.contains(where: { $0.id == page }) else { return }
        switch operation {
        case .legalConsent1(let url):
            legalConsent11(URLRequest(url: url), page: page)
        case .legalConsent2(let url):
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .legalConsent3:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .legalConsent4(let value):
            idleValues[page] = value
            legalConsent6()
        case .legalConsent5:
            legalConsent3(page)
        case .legalConsent6(let value):
            if let index = pages.firstIndex(where: { $0.id == page }) { pages[index].allowsBackForward = value }
            webView.allowsBackForwardNavigationGestures = value
        case .legalConsent7(let value):
            legalConsent7(value)
        case .legalConsent8:
            if legalConsent9 {
                legalConsent10 = { [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.legalConsent2(.legalConsent8, in: webView, page: page)
                }
                return
            }
            guard let nextURL else { notice = "Customer support is currently unavailable."; return }
            legalConsent2(.legalConsent1(nextURL), in: webView, page: page)
        }
    }

    func legalConsent3(_ page: UUID) {
        guard pages.contains(where: { $0.id == page }) else { return }
        if pages.count > 1 {
            let closed = pages.removeLast()
            idleValues.removeValue(forKey: closed.id)
            legalConsent6()
        } else {
            let close = onClose
            legalConsent4()
            close?()
        }
    }

    func legalConsent4() {
        revision += 1
        if let previousIdle { UIApplication.shared.isIdleTimerDisabled = previousIdle }
        pages.removeAll()
        idleValues.removeAll()
        source = nil
        rootURL = nil
        nextURL = nil
        previousIdle = nil
        onClose = nil
        notice = nil
        legalConsent9 = false
        legalConsent10 = nil
    }

    func legalConsent5(_ active: Bool) {
        isActive = active
        legalConsent6()
    }

    func legalConsent11(_ request: URLRequest, page: UUID) {
        guard pages.contains(where: { $0.id == page }), let url = request.url else { return }
        pages.append(LegalConsentPage(url: url, legalConsent2: request))
    }

    func legalConsent12() {
        guard pages.count > 1 else { return }
        let children = Set(pages.dropFirst().map(\.id))
        pages.removeSubrange(1...)
        idleValues = idleValues.filter { !children.contains($0.key) }
        legalConsent6()
    }

    private func legalConsent6() {
        guard let previousIdle else { return }
        let value = pages.reversed().compactMap { idleValues[$0.id] }.first ?? previousIdle
        UIApplication.shared.isIdleTimerDisabled = isActive ? value : previousIdle
    }

    private func legalConsent7(_ value: String) {
        guard let source else { notice = "Please refresh to update this session."; return }
        revision += 1
        let revision = self.revision
        legalConsent9 = true
        source.callAsyncJavaScript("return window.CraftkinActivity.privacyAndTerms(value)",
                                   arguments: ["value": value], in: nil, in: .page) { [weak self, weak source] result in
            guard let self, let source, self.source === source, self.revision == revision, !self.pages.isEmpty else { return }
            self.legalConsent9 = false
            guard case .success(let raw) = result, let body = raw as? [String: Any],
                  let entry = body["url"] as? String, let url = URL(string: entry) else {
                self.notice = "This session couldn’t be updated. Please refresh before reopening it."
                self.nextURL = nil
                self.legalConsent10 = nil
                return
            }
            let previous = self.rootURL
            self.rootURL = url
            self.nextURL = (body["supportURL"] as? String).flatMap(URL.init(string:))
            if let previous {
                for index in self.pages.indices {
                    if let next = LegalConsentValues.legalConsent9(self.pages[index].url, previous: previous, next: url) {
                        self.pages[index].url = next
                        self.pages[index].legalConsent2?.url = next
                    }
                }
            }
            self.pages[0].url = url
            let resume = self.legalConsent10
            self.legalConsent10 = nil
            resume?()
        }
    }
}
