import Foundation

public enum InitSignal {
    public static let sdkVersion = "0.1.0"

    public static func start(_ apiKey: String, configuration: Configuration = .init()) {
        Task.detached(priority: .background) {
            await InitSignalRuntime.shared.start(apiKey: apiKey, configuration: configuration)
        }
    }
}

public extension InitSignal {
    struct Configuration: Sendable {
        public let endpoint: URL
        public let requestTimeout: TimeInterval
        public let debugLogging: Bool

        let userDefaultsSuiteName: String?
        let retryPolicy: RetryPolicy
        let transport: (any FirstLaunchTransport)?

        public init(
            endpoint: URL = URL(string: "https://initsignal.com/api/v1/first-launch")!,
            requestTimeout: TimeInterval = 4,
            debugLogging: Bool = false
        ) {
            self.endpoint = endpoint
            self.requestTimeout = requestTimeout
            self.debugLogging = debugLogging
            self.userDefaultsSuiteName = nil
            self.retryPolicy = .default
            self.transport = nil
        }

        init(
            endpoint: URL,
            requestTimeout: TimeInterval = 4,
            debugLogging: Bool = false,
            userDefaultsSuiteName: String?,
            retryPolicy: RetryPolicy = .default,
            transport: (any FirstLaunchTransport)? = nil
        ) {
            self.endpoint = endpoint
            self.requestTimeout = requestTimeout
            self.debugLogging = debugLogging
            self.userDefaultsSuiteName = userDefaultsSuiteName
            self.retryPolicy = retryPolicy
            self.transport = transport
        }
    }
}

actor InitSignalRuntime {
    static let shared = InitSignalRuntime()

    private var didStart = false

    func start(apiKey: String, configuration: InitSignal.Configuration) async {
        guard didStart == false else { return }
        didStart = true

        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedApiKey.isEmpty == false else { return }

        let storage = FirstLaunchStorage(suiteName: configuration.userDefaultsSuiteName)
        guard storage.hasSent == false else { return }
        guard storage.canRetry(now: Date()) else { return }

        let eventUUID = storage.pendingEventUUID ?? UUID()
        storage.pendingEventUUID = eventUUID

        guard let payload = FirstLaunchPayload.current(eventUUID: eventUUID) else { return }

        do {
            let transport = configuration.transport ?? URLSessionFirstLaunchTransport()
            let statusCode = try await transport.send(
                payload: payload,
                apiKey: trimmedApiKey,
                endpoint: configuration.endpoint,
                timeout: configuration.requestTimeout
            )

            if (200..<300).contains(statusCode) {
                storage.markSent()
            } else {
                storage.recordFailure(now: Date(), retryPolicy: configuration.retryPolicy)
                log("InitSignal request failed with status \(statusCode)", configuration: configuration)
            }
        } catch {
            storage.recordFailure(now: Date(), retryPolicy: configuration.retryPolicy)
            log("InitSignal request failed: \(error)", configuration: configuration)
        }
    }

    private func log(_ message: String, configuration: InitSignal.Configuration) {
        guard configuration.debugLogging else { return }
        print("[InitSignal] \(message)")
    }
}

