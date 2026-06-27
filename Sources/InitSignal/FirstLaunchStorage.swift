import Foundation

final class FirstLaunchStorage {
    private enum Keys {
        static let hasSent = "com.initsignal.firstLaunch.hasSent"
        static let pendingOccurredAt = "com.initsignal.firstLaunch.pendingOccurredAt"
        static let nextRetryAfter = "com.initsignal.firstLaunch.nextRetryAfter"
        static let attemptCount = "com.initsignal.firstLaunch.attemptCount"
        static let legacyPendingEventUUID = "com.initsignal.firstLaunch.pendingEventUUID"
    }

    private let defaults: UserDefaults

    init(suiteName: String?) {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            self.defaults = defaults
        } else {
            self.defaults = .standard
        }

        defaults.removeObject(forKey: Keys.legacyPendingEventUUID)
    }

    var hasSent: Bool {
        defaults.bool(forKey: Keys.hasSent)
    }

    var pendingOccurredAt: Date? {
        get {
            defaults.object(forKey: Keys.pendingOccurredAt) as? Date
        }
        set {
            defaults.set(newValue, forKey: Keys.pendingOccurredAt)
        }
    }

    func canRetry(now: Date) -> Bool {
        guard let nextRetryAfter = defaults.object(forKey: Keys.nextRetryAfter) as? Date else {
            return true
        }

        return now >= nextRetryAfter
    }

    func markSent() {
        defaults.set(true, forKey: Keys.hasSent)
        defaults.removeObject(forKey: Keys.pendingOccurredAt)
        defaults.removeObject(forKey: Keys.nextRetryAfter)
        defaults.removeObject(forKey: Keys.attemptCount)
        defaults.removeObject(forKey: Keys.legacyPendingEventUUID)
    }

    func recordFailure(now: Date, retryPolicy: RetryPolicy) {
        let attemptCount = defaults.integer(forKey: Keys.attemptCount) + 1
        defaults.set(attemptCount, forKey: Keys.attemptCount)
        defaults.set(now.addingTimeInterval(retryPolicy.delay(afterFailureCount: attemptCount)), forKey: Keys.nextRetryAfter)
    }

    func resetForTests() {
        defaults.removeObject(forKey: Keys.hasSent)
        defaults.removeObject(forKey: Keys.pendingOccurredAt)
        defaults.removeObject(forKey: Keys.nextRetryAfter)
        defaults.removeObject(forKey: Keys.attemptCount)
        defaults.removeObject(forKey: Keys.legacyPendingEventUUID)
    }
}

struct RetryPolicy: Sendable {
    static let `default` = RetryPolicy(
        firstFailureDelay: 5 * 60,
        secondFailureDelay: 60 * 60,
        laterFailureDelay: 24 * 60 * 60
    )

    let firstFailureDelay: TimeInterval
    let secondFailureDelay: TimeInterval
    let laterFailureDelay: TimeInterval

    func delay(afterFailureCount failureCount: Int) -> TimeInterval {
        switch failureCount {
        case 1:
            return firstFailureDelay
        case 2:
            return secondFailureDelay
        default:
            return laterFailureDelay
        }
    }
}
