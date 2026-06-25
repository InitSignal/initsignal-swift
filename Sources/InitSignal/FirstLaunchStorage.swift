import Foundation

final class FirstLaunchStorage {
    private enum Keys {
        static let hasSent = "com.initsignal.firstLaunch.hasSent"
        static let pendingEventUUID = "com.initsignal.firstLaunch.pendingEventUUID"
        static let nextRetryAfter = "com.initsignal.firstLaunch.nextRetryAfter"
        static let attemptCount = "com.initsignal.firstLaunch.attemptCount"
    }

    private let defaults: UserDefaults

    init(suiteName: String?) {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            self.defaults = defaults
        } else {
            self.defaults = .standard
        }
    }

    var hasSent: Bool {
        defaults.bool(forKey: Keys.hasSent)
    }

    var pendingEventUUID: UUID? {
        get {
            guard let value = defaults.string(forKey: Keys.pendingEventUUID) else {
                return nil
            }

            return UUID(uuidString: value)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Keys.pendingEventUUID)
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
        defaults.removeObject(forKey: Keys.pendingEventUUID)
        defaults.removeObject(forKey: Keys.nextRetryAfter)
        defaults.removeObject(forKey: Keys.attemptCount)
    }

    func recordFailure(now: Date, retryPolicy: RetryPolicy) {
        let attemptCount = defaults.integer(forKey: Keys.attemptCount) + 1
        defaults.set(attemptCount, forKey: Keys.attemptCount)
        defaults.set(now.addingTimeInterval(retryPolicy.delay(afterFailureCount: attemptCount)), forKey: Keys.nextRetryAfter)
    }

    func resetForTests() {
        defaults.removeObject(forKey: Keys.hasSent)
        defaults.removeObject(forKey: Keys.pendingEventUUID)
        defaults.removeObject(forKey: Keys.nextRetryAfter)
        defaults.removeObject(forKey: Keys.attemptCount)
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

