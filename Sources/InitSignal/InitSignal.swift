import Foundation

public enum InitSignal {
    public static let sdkVersion = "0.2.0"

    public static func start(_ apiKey: String, configure: (inout Options) -> Void = { _ in }) {
        var options = Options(apiKey: apiKey)
        configure(&options)
        start(options)
    }

    public static func start(_ configure: (inout Options) -> Void) {
        var options = Options()
        configure(&options)
        start(options)
    }

    private static func start(_ options: Options) {
        Task.detached(priority: .background) {
            await InitSignalRuntime.shared.start(options: options)
        }
    }
}

public extension InitSignal {
    struct Options: Sendable {
        public var apiKey: String
        public var endpoint: URL
        public var requestTimeout: TimeInterval
        public var debug: Bool

        let userDefaultsSuiteName: String?
        let retryPolicy: RetryPolicy
        let transport: (any FirstLaunchTransport)?
        let isDevelopmentBuild: Bool

        public init(
            apiKey: String = "",
            endpoint: URL = URL(string: "https://initsignal.com/api/v1/first-launch")!,
            requestTimeout: TimeInterval = 4,
            debug: Bool = false
        ) {
            self.apiKey = apiKey
            self.endpoint = endpoint
            self.requestTimeout = requestTimeout
            self.debug = debug
            self.userDefaultsSuiteName = nil
            self.retryPolicy = .default
            self.transport = nil
            self.isDevelopmentBuild = BuildEnvironment.isDevelopmentBuild
        }

        init(
            apiKey: String = "",
            endpoint: URL,
            requestTimeout: TimeInterval = 4,
            debug: Bool = false,
            userDefaultsSuiteName: String?,
            retryPolicy: RetryPolicy = .default,
            transport: (any FirstLaunchTransport)? = nil,
            isDevelopmentBuild: Bool = false
        ) {
            self.apiKey = apiKey
            self.endpoint = endpoint
            self.requestTimeout = requestTimeout
            self.debug = debug
            self.userDefaultsSuiteName = userDefaultsSuiteName
            self.retryPolicy = retryPolicy
            self.transport = transport
            self.isDevelopmentBuild = isDevelopmentBuild
        }
    }

    typealias Configuration = Options
}

actor InitSignalRuntime {
    static let shared = InitSignalRuntime()

    private var didStart = false

    func start(options: InitSignal.Options) async {
        guard didStart == false else { return }
        didStart = true

        let trimmedApiKey = options.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedApiKey.isEmpty == false else { return }

        if options.isDevelopmentBuild {
            guard options.debug else { return }
            await sendDebugLaunch(apiKey: trimmedApiKey, options: options)
            return
        }

        let storage = FirstLaunchStorage(suiteName: options.userDefaultsSuiteName)
        guard storage.hasSent == false else { return }
        guard storage.canRetry(now: Date()) else { return }

        let eventUUID = storage.pendingEventUUID ?? UUID()
        storage.pendingEventUUID = eventUUID

        guard let payload = FirstLaunchPayload.current(eventUUID: eventUUID) else { return }

        do {
            let statusCode = try await send(payload: payload, apiKey: trimmedApiKey, options: options)

            if (200..<300).contains(statusCode) {
                storage.markSent()
                log("InitSignal first launch accepted", options: options)
            } else {
                storage.recordFailure(now: Date(), retryPolicy: options.retryPolicy)
                log("InitSignal request failed with status \(statusCode)", options: options)
            }
        } catch {
            storage.recordFailure(now: Date(), retryPolicy: options.retryPolicy)
            log("InitSignal request failed: \(error)", options: options)
        }
    }

    private func sendDebugLaunch(apiKey: String, options: InitSignal.Options) async {
        guard let payload = FirstLaunchPayload.current(eventUUID: UUID(), installSource: "development") else { return }
        log("Sending InitSignal debug launch", options: options)

        do {
            let statusCode = try await send(payload: payload, apiKey: apiKey, options: options)

            if (200..<300).contains(statusCode) {
                log("InitSignal debug launch accepted", options: options)
            } else {
                log("InitSignal debug launch failed with status \(statusCode)", options: options)
            }
        } catch {
            log("InitSignal debug launch failed: \(error)", options: options)
        }
    }

    private func send(payload: FirstLaunchPayload, apiKey: String, options: InitSignal.Options) async throws -> Int {
        let transport = options.transport ?? URLSessionFirstLaunchTransport()

        return try await transport.send(
            payload: payload,
            apiKey: apiKey,
            endpoint: options.endpoint,
            timeout: options.requestTimeout
        )
    }

    private func log(_ message: String, options: InitSignal.Options) {
        guard options.debug else { return }
        print("[InitSignal] \(message)")
    }
}

private enum BuildEnvironment {
    static var isDevelopmentBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
