import Foundation

protocol FirstLaunchTransport: Sendable {
    func send(payload: FirstLaunchPayload, appKey: String, endpoint: URL, timeout: TimeInterval) async throws -> Int
}

struct URLSessionFirstLaunchTransport: FirstLaunchTransport {
    func send(payload: FirstLaunchPayload, appKey: String, endpoint: URL, timeout: TimeInterval) async throws -> Int {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(appKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("InitSignalSwift/\(InitSignal.sdkVersion)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(payload)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil

        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let (_, response) = try await session.data(for: request)

        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
