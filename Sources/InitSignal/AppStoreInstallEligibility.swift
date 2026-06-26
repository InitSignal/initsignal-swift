import Foundation
import StoreKit

enum AppStoreInstallEligibility: Equatable, Sendable {
    case eligible
    case ineligible(String)
    case unknown(String)
}

protocol AppStoreInstallEligibilityChecking: Sendable {
    func eligibility() async -> AppStoreInstallEligibility
}

struct StoreKitAppStoreInstallEligibilityChecker: AppStoreInstallEligibilityChecking {
    func eligibility() async -> AppStoreInstallEligibility {
        do {
            let result = try await AppTransaction.shared

            switch result {
            case let .verified(appTransaction):
                return eligibility(forOriginalAppVersion: appTransaction.originalAppVersion)
            case let .unverified(_, error):
                return .unknown("App Store transaction could not be verified: \(error)")
            }
        } catch {
            return .unknown("App Store transaction unavailable: \(error)")
        }
    }

    private func eligibility(forOriginalAppVersion originalAppVersion: String) -> AppStoreInstallEligibility {
        let original = originalAppVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard original.isEmpty == false else {
            return .unknown("App Store original app version is empty")
        }

        guard let current = CurrentAppStoreVersion.value else {
            return .unknown("Current app version is unavailable")
        }

        if original == current {
            return .eligible
        }

        return .ineligible("Original app version \(original) does not match current app version \(current)")
    }
}

private enum CurrentAppStoreVersion {
    static var value: String? {
        let key: String

        #if os(macOS) && !targetEnvironment(macCatalyst)
        key = "CFBundleShortVersionString"
        #else
        key = "CFBundleVersion"
        #endif

        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
