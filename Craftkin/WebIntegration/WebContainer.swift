import SwiftUI
import WebKit

struct WebContainer: UIViewControllerRepresentable {
    let session: WebPreparedSession
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        Self.makeNavigationController(session: session, onClose: onClose)
    }

    static func makeNavigationController(session: WebPreparedSession, onClose: @escaping () -> Void) -> UINavigationController {
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let controller = WebPageController(url: session.entry, session: session, dataStore: dataStore,
                                           capabilities: WebDisabledCapabilities(), onClose: onClose)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.setNavigationBarHidden(true, animated: false)
        return navigation
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
    static func dismantleUIViewController(_ controller: UINavigationController, coordinator: ()) {
        for case let page as WebPageController in controller.viewControllers { page.stop() }
    }
}

@MainActor
final class WebPageController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let initialURL: URL
    private let session: WebPreparedSession
    private let dataStore: WKWebsiteDataStore
    private let capabilities: any WebOptionalCapabilities
    private let onClose: () -> Void
    private let showsNavigation: Bool
    private let suppliedConfiguration: WKWebViewConfiguration?
    private let loadsInitialPage: Bool
    private var browser: WKWebView!
    private let spinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private let failure = UIStackView()
    private let failureLabel = UILabel()
    private var timer: Task<Void, Never>?
    private var contentCheck: Task<Void, Never>?
    private var readiness = WebPageReadiness()
    private var requestTrace: WebRequestTrace?
    private var committedURL: URL?
    private var action: Task<Void, Never>?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var activePage = false
    private var completed = false
    private var idleState = WebIdleTimerState()

    init(url: URL, session: WebPreparedSession, dataStore: WKWebsiteDataStore,
         capabilities: any WebOptionalCapabilities, onClose: @escaping () -> Void,
         showsNavigation: Bool = false, configuration: WKWebViewConfiguration? = nil,
         loadsInitialPage: Bool = true) {
        self.initialURL = url; self.session = session; self.dataStore = dataStore
        self.capabilities = capabilities; self.onClose = onClose
        self.showsNavigation = showsNavigation
        self.suppliedConfiguration = configuration
        self.loadsInitialPage = loadsInitialPage
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = IntegrationConstants.Text.title
        let configuration = suppliedConfiguration ?? WKWebViewConfiguration()
        if suppliedConfiguration == nil { configuration.websiteDataStore = dataStore }
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        browser = WKWebView(frame: .zero, configuration: configuration)
        browser.navigationDelegate = self
        browser.uiDelegate = self
        browser.setAllMediaPlaybackSuspended(true)
        browser.scrollView.contentInsetAdjustmentBehavior = .never
        browser.scrollView.contentInset = .zero
        browser.scrollView.scrollIndicatorInsets = .zero
        browser.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browser)
        view.keyboardLayoutGuide.usesBottomSafeArea = false
        NSLayoutConstraint.activate([
            browser.topAnchor.constraint(equalTo: showsNavigation ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor),
            browser.leadingAnchor.constraint(equalTo: view.leadingAnchor), browser.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            browser.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        loadingLabel.text = IntegrationConstants.Text.loading
        loadingLabel.font = .preferredFont(forTextStyle: .body)
        loadingLabel.adjustsFontForContentSizeCategory = true
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingLabel)
        NSLayoutConstraint.activate([
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])
        configureFailure()
        let backImage = UIImage(systemName: IntegrationConstants.Symbol.back,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        let backButton = UIBarButtonItem(image: backImage, style: .plain, target: self, action: #selector(back))
        backButton.tintColor = .label
        backButton.accessibilityLabel = IntegrationConstants.Text.back
        navigationItem.leftBarButtonItem = backButton
        navigationItem.rightBarButtonItem = nil
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.restoreIdle() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.activateIdleIfNeeded() }
        }
        if loadsInitialPage { load(initialURL) }
        else { beginTrace(initialURL); beginLoading() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(!showsNavigation, animated: false)
        activePage = true
        activateIdleIfNeeded()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        activePage = false
        browser?.setAllMediaPlaybackSuspended(true)
        restoreIdle()
        action?.cancel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let captured: Bool
        if #available(iOS 18.0, *) {
            captured = traitCollection.sceneCaptureState == .active
        } else {
            captured = view.window?.windowScene?.screen.isCaptured ?? false
        }
        updateScreenPrivacy(active: UIApplication.shared.applicationState == .active, captured: captured)
    }

    func updateScreenPrivacy(active: Bool, captured: Bool) {
        browser?.setAllMediaPlaybackSuspended(!activePage || !active || captured)
    }

    private func configureFailure() {
        let label = failureLabel
        label.text = IntegrationConstants.Text.failed
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.accessibilityIdentifier = IntegrationConstants.Text.unavailableID
        let retry = UIButton(type: .system)
        retry.setTitle(IntegrationConstants.Text.retry, for: .normal)
        retry.addTarget(self, action: #selector(retryPage), for: .touchUpInside)
        retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let close = UIButton(type: .system)
        close.setTitle(IntegrationConstants.Text.close, for: .normal)
        close.accessibilityIdentifier = IntegrationConstants.Text.closeID
        close.addTarget(self, action: #selector(closeCurrentPage), for: .touchUpInside)
        close.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        failure.axis = .vertical; failure.spacing = 16; failure.alignment = .fill
        failure.addArrangedSubview(label); failure.addArrangedSubview(retry); failure.addArrangedSubview(close)
        failure.translatesAutoresizingMaskIntoConstraints = false
        failure.isHidden = true
        view.addSubview(failure)
        NSLayoutConstraint.activate([failure.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failure.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            failure.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28)])
    }

    private func load(_ url: URL) {
        beginTrace(url)
        guard WebBrowserAddress.isWebURL(url) else { showFailure(WebIntegrationError.addressDenied); return }
        beginLoading()
        browser.load(URLRequest(url: url))
    }

    private func beginTrace(_ url: URL) {
        requestTrace = WebRequestTrace(stage: .page, url: url, userID: session.session.userID)
        requestTrace?.emit(.start)
    }

    @objc private func retryPage() {
        if showsNavigation, let url = browser.url, WebBrowserAddress.isWebURL(url) {
            beginTrace(url)
            beginLoading()
            browser.reload()
        } else { load(initialURL) }
    }
    @objc private func closeCurrentPage() { closePage() }
    @objc private func closeAll() {
        for case let page as WebPageController in navigationController?.viewControllers ?? [] { page.stop() }
        onClose()
    }
    @objc private func back() {
        if browser.canGoBack { browser.goBack() }
        else { closePage() }
    }
    private func closePage() {
        if (navigationController?.viewControllers.count ?? 0) > 1 {
            stop()
            navigationController?.popViewController(animated: true)
        } else { closeAll() }
    }

    func stop() {
        if readiness.phase == .loading || readiness.phase == .rendering { requestTrace?.emit(.cancelled) }
        activePage = false; completed = false
        timer?.cancel(); action?.cancel()
        contentCheck?.cancel()
        readiness.cancel()
        committedURL = nil
        browser?.stopLoading()
        browser?.navigationDelegate = nil; browser?.uiDelegate = nil
        restoreIdle(ending: true)
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver); self.backgroundObserver = nil }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver); self.foregroundObserver = nil }
    }

    private var idleActivationAllowed: Bool {
        activePage && browser?.isHidden == false && UIApplication.shared.applicationState == .active
    }

    private func applyIdleValue(_ value: Bool?) {
        if let value { UIApplication.shared.isIdleTimerDisabled = value }
    }

    private func activateIdleIfNeeded() {
        let value = idleState.activate(active: idleActivationAllowed, currentValue: UIApplication.shared.isIdleTimerDisabled)
        applyIdleValue(value)
    }

    private func restoreIdle(ending: Bool = false) {
        applyIdleValue(ending ? idleState.end() : idleState.suspend())
    }

    private func showFailure(_ error: Error? = nil) {
        requestTrace?.emit(.failure, error: error ?? WebIntegrationError.network)
        timer?.cancel(); completed = false
        contentCheck?.cancel()
        readiness.fail()
        loadingLabel.isHidden = true
        spinner.stopAnimating(); browser.isHidden = true; failure.isHidden = false
        failureLabel.text = (error as? WebIntegrationError) == .emptyPage
            ? IntegrationConstants.Text.emptyPage : IntegrationConstants.Text.failed
        #if DEBUG
        let report = WebStartupFailure(stage: .page, error: error ?? WebIntegrationError.network)
        failureLabel.text = (failureLabel.text ?? IntegrationConstants.Text.failed) + "\n" + report.reference
        #endif
        restoreIdle(ending: true)
    }

    private func notice(_ error: Error, destination: URL? = nil, command: WebBridgeCommand? = nil,
                        context: String? = nil) {
        guard presentedViewController == nil, activePage else { return }
        var message = (error as? WebIntegrationError) == .addressDenied ? IntegrationConstants.Text.denied : IntegrationConstants.Text.unsupported
        #if DEBUG
        message += "\n" + WebStartupFailure(stage: .page, error: error).reference
        let actionID = command?.actionID ?? destination.map(WebBridgeParser.actionID)
        if let actionID {
            message += "\n" + IntegrationConstants.Diagnostic.action + ": " + actionID
        }
        if let context {
            message += "\n" + IntegrationConstants.Diagnostic.context + ": " + context
        }
        if let destination, let origin = WebEndpointSummary(values: [destination.absoluteString]).webOrigin {
            message += "\n" + origin
        }
        #endif
        let alert = UIAlertController(title: IntegrationConstants.Text.issue, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: IntegrationConstants.Text.okay, style: .default))
        present(alert, animated: true)
    }

    private func execute(_ command: WebBridgeCommand) throws {
        switch command {
        case .ignored: return
        case .endSession: closeAll()
        case .close: closePage()
        case .settings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { throw WebIntegrationError.unsupported }
            UIApplication.shared.open(url)
        case .keepAwake(let enabled):
            let value = idleState.request(enabled, active: idleActivationAllowed,
                currentValue: UIApplication.shared.isIdleTimerDisabled)
            applyIdleValue(value)
        case .history(let enabled): browser.allowsBackForwardNavigationGestures = enabled
        case .internalPage, .externalPage: try openLink(command)
        case .contact:
            guard let identifier = session.services.contactID, !identifier.isEmpty,
                  let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
                  let prefix = session.entry.absoluteString.split(separator: "#", maxSplits: 1).first,
                  let url = URL(string: String(prefix) + IntegrationConstants.Route.contact + encoded) else { throw WebIntegrationError.unsupported }
            try openChild(url)
        case .event, .transaction:
            guard action == nil else { throw WebIntegrationError.unsupported }
            action = Task { [weak self] in
                guard let self else { return }
                defer { self.action = nil }
                do { try await self.capabilities.perform(command) }
                catch {
                    if !Task.isCancelled {
                        self.notice(error, command: command, context: IntegrationConstants.Diagnostic.capability)
                    }
                }
            }
        }
    }

    private func openLink(_ command: WebBridgeCommand) throws {
        try openDestination(WebLinkRouter(policy: session.environment.webPolicy).destination(for: command))
    }

    private func openDestination(_ destination: WebLinkDestination) throws {
        switch destination {
        case .page(let url), .browser(let url): try openChild(url)
        case .system(let url):
            UIApplication.shared.open(url, options: [:]) { [weak self] opened in
                guard !opened else { return }
                Task { @MainActor [weak self] in self?.notice(WebIntegrationError.unsupported, destination: url) }
            }
        }
    }

    private func openChild(_ url: URL) throws {
        guard WebBrowserAddress.isWebURL(url), (navigationController?.viewControllers.count ?? 0) < 5 else {
            throw WebIntegrationError.addressDenied
        }
        navigationController?.pushViewController(WebPageController(url: url, session: session, dataStore: dataStore,
            capabilities: capabilities, onClose: onClose, showsNavigation: true), animated: true)
    }

    private func sourceSnapshot(_ frame: WKFrameInfo?) -> WebFrameSource {
        guard let frame else { return .unavailable }
        let origin = frame.securityOrigin
        return WebFrameSource(mainFrame: frame.isMainFrame, scheme: origin.protocol,
                              host: origin.host, port: origin.port)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        // Snapshot frame metadata before resolving the navigation decision.
        let frame = sourceSnapshot(navigationAction.sourceFrame)
        let source = frame.trustedPageURL(committedURL, policy: session.environment.webPolicy)
        let pageSource = frame.matchingPageURL(committedURL)
        let targetMainFrame = navigationAction.targetFrame?.isMainFrame
        let userActivated = navigationAction.navigationType == .linkActivated
        if url.scheme == IntegrationConstants.Bridge.scheme {
            let availability: WebBridgeAvailability = !activePage || browser.isHidden ? .hidden
                : (completed && !webView.isLoading ? .ready : .loading)
            decisionHandler(.cancel)
            var command: WebBridgeCommand?
            do {
                let parsed: WebBridgeCommand
                if source == nil {
                    parsed = try WebBridgeParser(policy: session.environment.webPolicy).parseBrowser(url,
                        source: pageSource, mainFrame: frame.mainFrame, availability: availability)
                } else {
                    parsed = try WebBridgeParser(policy: session.environment.webPolicy).parse(url,
                        source: source, mainFrame: frame.mainFrame, availability: availability)
                }
                command = parsed
                try execute(parsed)
            } catch {
                notice(error, destination: url, command: command, context: IntegrationConstants.Diagnostic.bridge)
            }
            return
        }
        let route = WebLinkRouter(policy: session.environment.webPolicy).navigation(to: url,
            source: pageSource, sourceMainFrame: frame.mainFrame, targetMainFrame: targetMainFrame,
            userActivated: userActivated, active: activePage, initialDocument: initialURL)
        switch route {
        case .allow: decisionHandler(.allow)
        case .cancel: decisionHandler(.cancel)
        case .deny:
            decisionHandler(.cancel)
            notice(WebIntegrationError.addressDenied, destination: url)
        case .open(let destination):
            decisionHandler(.cancel)
            do { try openDestination(destination) }
            catch { notice(error, destination: url) }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse {
            requestTrace?.emit(.response, httpStatus: response.statusCode)
        }
        guard let url = navigationResponse.response.url,
              WebBrowserAddress.isWebURL(url) || url.absoluteString == IntegrationConstants.Route.blank,
              navigationResponse.canShowMIMEType else {
            decisionHandler(.cancel)
            if navigationResponse.isForMainFrame { showFailure() }
            return
        }
        if let response = navigationResponse.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            decisionHandler(.cancel)
            if navigationResponse.isForMainFrame {
                showFailure(WebTransportFailure(reason: .network, httpStatus: response.statusCode))
            }
            return
        }
        decisionHandler(.allow)
    }

    private func beginLoading() {
        readiness.begin()
        contentCheck?.cancel()
        completed = false; spinner.startAnimating(); failure.isHidden = true; browser.isHidden = false
        loadingLabel.isHidden = false
        timer?.cancel()
        timer = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: IntegrationConstants.Limit.navigation) } catch { return }
            guard !Task.isCancelled, let self,
                  self.readiness.phase == .loading || self.readiness.phase == .rendering else { return }
            let reason = self.readiness.timeoutReason
            self.browser.stopLoading()
            if reason == .emptyPage { self.showFailure(reason) }
            else { self.showFailure(URLError(.timedOut)) }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if readiness.phase != .loading { beginTrace(webView.url ?? initialURL) }
        beginLoading()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        committedURL = webView.url.flatMap { WebBrowserAddress.isWebURL($0) ? $0 : nil }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        readiness.finishDocument()
        guard readiness.phase == .rendering else { return }
        if showsNavigation, let pageTitle = webView.title, !pageTitle.isEmpty { title = pageTitle }
        requestTrace?.emit(.document)
        completed = true
        contentCheck?.cancel()
        contentCheck = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.readiness.phase == .rendering else { return }
                do {
                    let result = try await self.browser.evaluateJavaScript(IntegrationConstants.Script.renderedContent)
                    guard !Task.isCancelled else { return }
                    if self.readiness.observeContent(visible: (result as? Bool) == true) {
                        self.requestTrace?.emit(.content)
                        self.timer?.cancel()
                        self.spinner.stopAnimating()
                        self.loadingLabel.isHidden = true
                        return
                    }
                    try await Task.sleep(nanoseconds: IntegrationConstants.Limit.contentProbe)
                } catch is CancellationError { return }
                catch {
                    guard !Task.isCancelled else { return }
                    self.showFailure(WebIntegrationError.emptyPage)
                    return
                }
            }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showFailure(error) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showFailure(error) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { showFailure() }
    func webViewDidClose(_ webView: WKWebView) { closePage() }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let frame = sourceSnapshot(navigationAction.sourceFrame)
        guard activePage, frame.matchingPageURL(committedURL) != nil,
              let url = navigationAction.request.url,
              WebBrowserAddress.isWebURL(url) || url.absoluteString == IntegrationConstants.Route.blank,
              let navigation = navigationController, navigation.viewControllers.count < 5 else { return nil }
        let child = WebPageController(url: url, session: session, dataStore: configuration.websiteDataStore,
            capabilities: capabilities, onClose: onClose, showsNavigation: true,
            configuration: configuration, loadsInitialPage: false)
        child.loadViewIfNeeded()
        navigation.pushViewController(child, animated: true)
        // WebKit loads its original request in this view, including form submissions.
        return child.browser
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let snapshot = sourceSnapshot(frame)
        guard activePage, completed,
              let source = snapshot.trustedPageURL(committedURL, policy: session.environment.webPolicy),
              origin.protocol == IntegrationConstants.Route.secure,
              origin.host.lowercased() == source.host?.lowercased(), origin.port == 0 || origin.port == 443 else {
            decisionHandler(.deny); return
        }
        decisionHandler(.prompt)
    }

    deinit {
        timer?.cancel(); contentCheck?.cancel(); action?.cancel()
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }
}
