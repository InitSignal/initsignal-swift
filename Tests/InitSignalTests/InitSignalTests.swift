import Foundation
@testable import InitSignal
import XCTest

final class InitSignalTests: XCTestCase {
    func testStorefrontCountryCodeIsNormalizedAndEncoded() throws {
        XCTAssertEqual(AppStorefront.normalizedCountryCode(" usa "), "USA")
        XCTAssertNil(AppStorefront.normalizedCountryCode("US"))
        XCTAssertNil(AppStorefront.normalizedCountryCode(""))

        let payload = FirstLaunchPayload(
            bundleId: "com.example.app",
            appVersion: "1.0.0",
            buildNumber: "1",
            platform: "iOS",
            osVersion: "18.0",
            deviceFamily: "iPhone",
            deviceModel: "iPhone14,7",
            appLocale: "en-US",
            appStorefrontCountryCode: "USA",
            timestamp: "2026-07-06T12:00:00.000Z",
            sdkVersion: "test",
            installSource: "app-store"
        )

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["appStorefrontCountryCode"] as? String, "USA")
    }

    func testStartSendsOnceAndMarksSent() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let options = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport,
            eligibilityChecker: MockEligibilityChecker(.eligible)
        )

        await runtime.start(options: options)
        await runtime.start(options: options)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 1)
        XCTAssertTrue(storage.hasSent)
        XCTAssertNil(storage.pendingOccurredAt)
    }

    func testFailureKeepsPendingTimestampForLaterRetry() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let failingTransport = MockTransport(results: [.failure(MockError.offline)])
        let firstRuntime = InitSignalRuntime()
        let firstOptions = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: failingTransport,
            eligibilityChecker: MockEligibilityChecker(.eligible)
        )

        await firstRuntime.start(options: firstOptions)

        let failedPayloads = await failingTransport.payloads
        XCTAssertEqual(failedPayloads.count, 1)
        XCTAssertFalse(storage.hasSent)
        XCTAssertNotNil(storage.pendingOccurredAt)

        let retryTransport = MockTransport(results: [.success(202)])
        let retryRuntime = InitSignalRuntime()
        let retryOptions = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: retryTransport,
            eligibilityChecker: MockEligibilityChecker(.eligible)
        )

        await retryRuntime.start(options: retryOptions)

        let retriedPayloads = await retryTransport.payloads
        XCTAssertEqual(retriedPayloads.count, 1)
        XCTAssertEqual(failedPayloads.first?.timestamp, retriedPayloads.first?.timestamp)
        XCTAssertTrue(storage.hasSent)
    }

    func testSentFlagPreventsNetworkRequest() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()
        storage.markSent()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let options = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport,
            eligibilityChecker: MockEligibilityChecker(.eligible)
        )

        await runtime.start(options: options)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 0)
    }

    func testIneligibleOriginalAppVersionSkipsNetworkRequest() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let options = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport,
            eligibilityChecker: MockEligibilityChecker(.ineligible("existing install"))
        )

        await runtime.start(options: options)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 0)
        XCTAssertFalse(storage.hasSent)
        XCTAssertNil(storage.pendingOccurredAt)
    }

    func testUnknownOriginalAppVersionDefersWithoutPayload() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let options = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport,
            eligibilityChecker: MockEligibilityChecker(.unknown("transaction unavailable"))
        )

        await runtime.start(options: options)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 0)
        XCTAssertFalse(storage.hasSent)
        XCTAssertNil(storage.pendingOccurredAt)
    }

    func testDevelopmentBuildWithoutDebugDoesNotSend() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let transport = MockTransport(results: [.success(202)])
        let runtime = InitSignalRuntime()
        let options = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport,
            eligibilityChecker: MockEligibilityChecker(.eligible),
            isDevelopmentBuild: true
        )

        await runtime.start(options: options)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 0)
        XCTAssertFalse(storage.hasSent)
        XCTAssertNil(storage.pendingOccurredAt)
    }

    func testDebugDevelopmentBuildSendsFreshEventPerLaunch() async {
        let suiteName = "InitSignalTests.\(UUID().uuidString)"
        let storage = FirstLaunchStorage(suiteName: suiteName)
        storage.resetForTests()

        let transport = MockTransport(results: [.success(202), .success(202)])
        let options = InitSignal.Configuration(
            appKey: "is_live_test",
            endpoint: URL(string: "https://example.com/first-launch")!,
            debug: true,
            userDefaultsSuiteName: suiteName,
            retryPolicy: .immediate,
            transport: transport,
            eligibilityChecker: MockEligibilityChecker(.ineligible("existing install")),
            isDevelopmentBuild: true
        )

        await InitSignalRuntime().start(options: options)
        await InitSignalRuntime().start(options: options)

        let payloads = await transport.payloads
        XCTAssertEqual(payloads.count, 2)
        XCTAssertEqual(payloads.map(\.installSource), ["development", "development"])
        XCTAssertTrue(payloads.allSatisfy { $0.appStorefrontCountryCode == nil })
        XCTAssertFalse(storage.hasSent)
        XCTAssertNil(storage.pendingOccurredAt)
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

    func send(payload: FirstLaunchPayload, appKey: String, endpoint: URL, timeout: TimeInterval) async throws -> Int {
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

private struct MockEligibilityChecker: AppStoreInstallEligibilityChecking {
    let result: AppStoreInstallEligibility

    init(_ result: AppStoreInstallEligibility) {
        self.result = result
    }

    func eligibility() async -> AppStoreInstallEligibility {
        result
    }
}

private extension RetryPolicy {
    static let immediate = RetryPolicy(firstFailureDelay: 0, secondFailureDelay: 0, laterFailureDelay: 0)
}
