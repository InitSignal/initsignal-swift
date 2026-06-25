import Foundation

struct FirstLaunchPayload: Encodable, Equatable, Sendable {
    let bundleId: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    let deviceFamily: String
    let deviceModel: String
    let appLocale: String
    let timestamp: String
    let sdkVersion: String
    let installSource: String?
    let eventUuid: UUID

    static func current(eventUUID: UUID, bundle: Bundle = .main, date: Date = Date()) -> FirstLaunchPayload? {
        guard let bundleId = bundle.bundleIdentifier, bundleId.isEmpty == false else {
            return nil
        }

        return FirstLaunchPayload(
            bundleId: bundleId,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            platform: DeviceInfo.platform,
            osVersion: DeviceInfo.osVersion,
            deviceFamily: DeviceInfo.deviceFamily,
            deviceModel: DeviceInfo.deviceModel,
            appLocale: Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
            timestamp: ISO8601.string(from: date),
            sdkVersion: InitSignal.sdkVersion,
            installSource: InstallSource.detect(bundle: bundle),
            eventUuid: eventUUID
        )
    }
}

private enum ISO8601 {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
