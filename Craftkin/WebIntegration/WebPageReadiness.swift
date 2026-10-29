import Foundation

struct WebPageReadiness {
    enum Phase { case idle, loading, rendering, ready, failed }
    private(set) var phase: Phase = .idle

    mutating func begin() { phase = .loading }
    mutating func finishDocument() {
        guard phase == .loading else { return }
        phase = .rendering
    }
    mutating func observeContent(visible: Bool) -> Bool {
        guard phase == .rendering, visible else { return false }
        phase = .ready
        return true
    }
    mutating func fail() { phase = .failed }
    mutating func cancel() { phase = .idle }

    var timeoutReason: WebIntegrationError { phase == .rendering ? .emptyPage : .network }
}
