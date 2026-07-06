import Foundation
import StoreKit

struct FirstLaunchPayload: Encodable, Equatable, Sendable {
    let bundleId: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    let deviceFamily: String
    let deviceModel: String
    let appLocale: String
    let appStorefrontCountryCode: String?
    let timestamp: String
    let sdkVersion: String
    let installSource: String?

    static func current(
        installSource: String? = nil,
        bundle: Bundle = .main,
        date: Date = Date()
    ) async -> FirstLaunchPayload? {
        return make(
            installSource: installSource,
            bundle: bundle,
            date: date,
            appStorefrontCountryCode: await AppStorefront.countryCode()
        )
    }

    static func make(
        installSource: String? = nil,
        bundle: Bundle = .main,
        date: Date = Date(),
        appStorefrontCountryCode: String?
    ) -> FirstLaunchPayload? {
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
            appStorefrontCountryCode: AppStorefront.normalizedCountryCode(appStorefrontCountryCode),
            timestamp: ISO8601.string(from: date),
            sdkVersion: InitSignal.sdkVersion,
            installSource: installSource ?? InstallSource.detect(bundle: bundle)
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

enum AppStorefront {
    static func countryCode() async -> String? {
        guard let storefront = await Storefront.current else {
            return nil
        }

        return normalizedCountryCode(storefront.countryCode)
    }

    static func normalizedCountryCode(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        guard normalized.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else {
            return nil
        }

        return normalized
    }
}
