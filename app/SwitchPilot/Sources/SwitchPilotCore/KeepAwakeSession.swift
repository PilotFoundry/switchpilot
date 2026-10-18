import Foundation

public enum KeepAwakeError: Error, Equatable, CustomStringConvertible {
    case invalidDuration

    public var description: String {
        switch self {
        case .invalidDuration: return "duration must be a finite number of seconds greater than zero"
        }
    }
}

public enum KeepAwakePreset: Int, CaseIterable, Identifiable, Hashable {
    case minutes15 = 15
    case minutes30 = 30
    case minutes60 = 60
    case unlimited = -1

    public var id: Int { rawValue }

    public var minutes: Int? {
        self == .unlimited ? nil : rawValue
    }

    public var label: String {
        switch self {
        case .minutes15: return "15 分钟"
        case .minutes30: return "30 分钟"
        case .minutes60: return "60 分钟"
        case .unlimited: return "无限期"
        }
    }
}

/// Owns a Keep Awake session: one real power assertion plus an optional countdown.
public final class KeepAwakeSession {
    public private(set) var assertion: PowerAssertion
    public private(set) var endDate: Date?
    public private(set) var totalSeconds: TimeInterval?
    public var onChange: (() -> Void)?
    private var timer: Timer?

    public init(assertion: PowerAssertion = PowerAssertion()) {
        self.assertion = assertion
    }

    public var isActive: Bool { assertion.isActive }
    public var liveAssertionID: IOPMAssertionID? { assertion.id }

    /// nil means indefinite (until stop/quit).
    public var remainingSeconds: Int? {
        guard let endDate else { return nil }
        return max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    public func start(minutes: Int?) throws {
        try start(seconds: minutes.map { TimeInterval($0 * 60) })
    }

    /// Test/configuration hook: rejects non-positive or non-finite durations.
    public func start(seconds: TimeInterval?) throws {
        if let seconds {
            guard seconds.isFinite, seconds > 0 else { throw KeepAwakeError.invalidDuration }
        }
        stop()
        try assertion.start()
        totalSeconds = seconds
        endDate = seconds.map { Date().addingTimeInterval($0) }
        if seconds != nil { scheduleTimer() }
        onChange?()
    }

    /// 1.0 right after start, decreasing toward 0; nil for indefinite sessions.
    public var fractionRemaining: Double? {
        guard let totalSeconds, let remaining = remainingSeconds, totalSeconds > 0 else { return nil }
        return min(1, max(0, Double(remaining) / totalSeconds))
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        totalSeconds = nil
        try? assertion.stop()
        onChange?()
    }

    private func scheduleTimer() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let endDate else { return }
        if Date() >= endDate {
            stop()
        } else {
            onChange?()
        }
    }
}
