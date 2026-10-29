import Foundation

struct WebIdleTimerState {
    private var requested = false
    private var previousValue: Bool?

    init() {}

    mutating func request(_ enabled: Bool, active: Bool, currentValue: Bool) -> Bool? {
        requested = enabled
        return enabled ? activate(active: active, currentValue: currentValue) : suspend()
    }

    mutating func activate(active: Bool, currentValue: Bool) -> Bool? {
        guard active, requested else { return nil }
        if previousValue == nil { previousValue = currentValue }
        return true
    }

    mutating func suspend() -> Bool? {
        let value = previousValue
        previousValue = nil
        return value
    }

    mutating func end() -> Bool? {
        requested = false
        return suspend()
    }
}
