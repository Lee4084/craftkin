import UIKit

/// Uses public capture notifications. A screenshot notification arrives after capture;
/// the notice cannot prevent or delete the screenshot that triggered it.
@MainActor
final class ScreenPrivacyController: NSObject {
    private weak var scene: UIWindowScene?
    private weak var contentWindow: UIWindow?
    private let shield: UIWindow
    private let content = ScreenPrivacyNoticeController()
    private var state = ScreenPrivacyState()
    private var active = false

    init(scene: UIWindowScene, contentWindow: UIWindow) {
        self.scene = scene
        self.contentWindow = contentWindow
        shield = ScreenPrivacyWindow(windowScene: scene)
        super.init()
        shield.frame = scene.coordinateSpace.bounds
        shield.windowLevel = .alert + 1
        shield.rootViewController = content
        shield.overrideUserInterfaceStyle = .light
        content.onContinue = { [weak self] in
            self?.state.dismissScreenshot()
            self?.render()
        }
        content.onCaptureChanged = { [weak self] in self?.refresh() }
        NotificationCenter.default.addObserver(self, selector: #selector(captureChanged(_:)),
                                               name: UIScreen.capturedDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenshotTaken),
                                               name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        setActive(scene.activationState == .foregroundActive)
    }

    func setActive(_ active: Bool) {
        self.active = active
        refresh()
    }

    @objc private func captureChanged(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen, screen === scene?.screen else { return }
        refresh()
    }

    @objc private func screenshotTaken() {
        state.screenshotTaken()
        render()
    }

    private func refresh() {
        guard let scene else { return }
        let captured: Bool
        if #available(iOS 18.0, *) {
            captured = scene.traitCollection.sceneCaptureState == .active
        } else {
            captured = scene.screen.isCaptured
        }
        state.update(active: active, captured: captured)
        updateMedia(in: contentWindow?.rootViewController, captured: captured)
        render()
    }

    private func updateMedia(in controller: UIViewController?, captured: Bool) {
        guard let controller else { return }
        (controller as? WebPageController)?.updateScreenPrivacy(active: active, captured: captured)
        for child in controller.children { updateMedia(in: child, captured: captured) }
        if let presented = controller.presentedViewController { updateMedia(in: presented, captured: captured) }
    }

    private func render() {
        content.show(state.cover)
        // A separate scene-bound window covers root replacements and pushed browser pages
        // without reparenting the app's windows, layers or WebKit views.
        shield.isHidden = state.cover == nil
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        shield.isHidden = true
        shield.rootViewController = nil
        content.onContinue = nil
        content.onCaptureChanged = nil
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

private final class ScreenPrivacyWindow: UIWindow {
    override var canBecomeKey: Bool { false }
}

@MainActor
private final class ScreenPrivacyNoticeController: UIViewController {
    var onContinue: (() -> Void)?
    var onCaptureChanged: (() -> Void)?
    private let label = UILabel()
    private let button = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityViewIsModal = true
        view.accessibilityIdentifier = "screen-privacy-cover"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        button.setTitle(String(localized: "Continue"), for: .normal)
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
        registerForTraitChanges([UITraitSceneCaptureState.self]) { (self: ScreenPrivacyNoticeController, _: UITraitCollection) in
            self.onCaptureChanged?()
        }
    }

    func show(_ cover: ScreenPrivacyState.Cover?) {
        loadViewIfNeeded()
        switch cover {
        case .inactive: label.text = String(localized: "Content hidden for privacy.")
        case .recording: label.text = String(localized: "Screen recording or mirroring is active. Stop sharing your screen to continue.")
        case .screenshot: label.text = String(localized: "Screenshot detected. Screenshots may contain private information. Please keep them secure.")
        case nil: label.text = nil
        }
        button.isHidden = cover != .screenshot
    }

    @objc private func continueTapped() { onContinue?() }
}
