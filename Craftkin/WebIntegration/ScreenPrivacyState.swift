import Foundation

struct ScreenPrivacyState {
    enum Cover: Equatable { case inactive, recording, screenshot }
    private var active = false
    private var captured = false
    private var showsScreenshotNotice = false

    var cover: Cover? {
        if !active { return .inactive }
        if captured { return .recording }
        return showsScreenshotNotice ? .screenshot : nil
    }

    mutating func update(active: Bool, captured: Bool) {
        self.active = active
        self.captured = captured
        if !active { showsScreenshotNotice = false }
    }

    mutating func screenshotTaken() {
        if active && !captured { showsScreenshotNotice = true }
    }

    mutating func dismissScreenshot() { showsScreenshotNotice = false }
}
