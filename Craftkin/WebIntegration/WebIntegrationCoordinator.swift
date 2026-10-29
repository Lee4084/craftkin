import Foundation
import Combine

@MainActor
final class WebIntegrationCoordinator: ObservableObject {
    enum State: Equatable { case idle, connecting, native, ready, failed(WebIntegrationError) }
    @Published private(set) var state: State = .idle
    @Published private(set) var prepared: WebPreparedSession?
    @Published private(set) var diagnostic: WebStartupFailure?
    private let makeService: () throws -> any WebSessionPreparing
    private var work: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var generation = UUID()
    private let timeout: UInt64

    init(timeout: UInt64? = nil, makeService: @escaping () throws -> any WebSessionPreparing) {
        self.timeout = timeout ?? IntegrationConstants.Limit.startup
        self.makeService = makeService
    }

    func start() {
        cancel()
        let attempt = UUID()
        generation = attempt
        state = .connecting
        do {
            let service = try makeService()
            work = Task { [weak self] in
                do {
                    let result = try await service.prepare()
                    guard !Task.isCancelled, let self, self.generation == attempt else { return }
                    self.deadline?.cancel()
                    self.prepared = result
                    self.state = result == nil ? .native : .ready
                } catch {
                    guard !Task.isCancelled, let self, self.generation == attempt else { return }
                    self.deadline?.cancel()
                    self.diagnostic = error as? WebStartupFailure ?? WebStartupFailure(stage: .setup, error: error)
                    self.state = .failed(self.diagnostic?.reason ?? .network)
                }
            }
            deadline = Task { [weak self, timeout] in
                do { try await Task.sleep(nanoseconds: timeout) } catch { return }
                guard let self, self.generation == attempt, self.state == .connecting else { return }
                self.work?.cancel()
                self.generation = UUID()
                self.diagnostic = WebStartupFailure(stage: .setup, error: URLError(.timedOut))
                self.state = .failed(.network)
            }
        } catch {
            diagnostic = WebStartupFailure(stage: .setup, error: error)
            state = .failed((error as? WebIntegrationError) ?? .unavailable)
        }
    }

    func cancel() {
        generation = UUID()
        work?.cancel(); work = nil
        deadline?.cancel(); deadline = nil
        prepared = nil
        diagnostic = nil
        state = .idle
    }

    deinit { work?.cancel(); deadline?.cancel() }
}
