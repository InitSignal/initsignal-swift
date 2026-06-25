import Foundation
@testable import InitSignal
import XCTest

final class InitSignalTests: XCTestCase {
    func testStartSendsOnceAndMarksSent() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let configuration = InitSignal.Configuration(
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport
        )

        await runtime.start(apiKey: "is_live_test", configuration: configuration)
        await runtime.start(apiKey: "is_live_test", configuration: configuration)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 1)
        XCTAssertTrue(storage.hasSent)
        XCTAssertNil(storage.pendingEventUUID)
    }

    func testFailureKeepsPendingUuidForLaterRetry() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let failingTransport = MockTransport(results: [.failure(MockError.offline)])
        let firstRuntime = InitSignalRuntime()
        let firstConfiguration = InitSignal.Configuration(
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: failingTransport
        )

        await firstRuntime.start(apiKey: "is_live_test", configuration: firstConfiguration)

        let failedPayloads = await failingTransport.payloads
        XCTAssertEqual(failedPayloads.count, 1)
        XCTAssertFalse(storage.hasSent)
        XCTAssertNotNil(storage.pendingEventUUID)

        let retryTransport = MockTransport(results: [.success(202)])
        let retryRuntime = InitSignalRuntime()
        let retryConfiguration = InitSignal.Configuration(
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: retryTransport
        )

        await retryRuntime.start(apiKey: "is_live_test", configuration: retryConfiguration)

        let retriedPayloads = await retryTransport.payloads
        XCTAssertEqual(retriedPayloads.count, 1)
        XCTAssertEqual(failedPayloads.first?.eventUuid, retriedPayloads.first?.eventUuid)
        XCTAssertTrue(storage.hasSent)
    }

    func testSentFlagPreventsNetworkRequest() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()
        storage.markSent()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let configuration = InitSignal.Configuration(
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport
        )

        await runtime.start(apiKey: "is_live_test", configuration: configuration)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 0)
    }
}

private actor MockTransport: FirstLaunchTransport {
    enum Result {
        case success(Int)
        case failure(Error)
    }

    private(set) var payloads: [FirstLaunchPayload] = []
    private var results: [Result]

    init(results: [Result]) {
        self.results = results
    }

    func send(payload: FirstLaunchPayload, apiKey: String, endpoint: URL, timeout: TimeInterval) async throws -> Int {
        payloads.append(payload)

        let result = results.isEmpty ? .success(202) : results.removeFirst()

        switch result {
        case let .success(statusCode):
            return statusCode
        case let .failure(error):
            throw error
        }
    }
}

private enum MockError: Error {
    case offline
}

private extension RetryPolicy {
    static let immediate = RetryPolicy(firstFailureDelay: 0, secondFailureDelay: 0, laterFailureDelay: 0)
}

