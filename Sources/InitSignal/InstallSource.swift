import Foundation

enum InstallSource {
    static func detect(bundle: Bundle) -> String? {
        guard
            let receiptURL = bundle.appStoreReceiptURL,
            FileManager.default.fileExists(atPath: receiptURL.path)
        else {
            return nil
        }

        if receiptURL.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }

        #if os(macOS) || targetEnvironment(macCatalyst)
        return "mac-app-store"
        #else
        return "app-store"
        #endif
    }
}

