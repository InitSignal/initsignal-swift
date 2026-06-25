import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum DeviceInfo {
    static var platform: String {
        #if targetEnvironment(macCatalyst)
        return "macOS"
        #elseif os(iOS)
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #else
        return "iOS"
        #endif
        #elseif os(macOS)
        return "macOS"
        #else
        return "iOS"
        #endif
    }

    static var deviceFamily: String {
        #if targetEnvironment(macCatalyst)
        return "Mac"
        #elseif os(iOS)
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        return "iPhone"
        #endif
        #elseif os(macOS)
        return "Mac"
        #else
        return "iPhone"
        #endif
    }

    static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    static var deviceModel: String {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return sysctlString(named: "hw.model") ?? "Mac"
        #else
        return sysctlString(named: "hw.machine") ?? deviceFamily
        #endif
    }

    private static func sysctlString(named name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        return String(cString: buffer)
    }
}

