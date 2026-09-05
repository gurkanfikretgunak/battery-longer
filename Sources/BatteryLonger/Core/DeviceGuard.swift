import Foundation
import IOKit

/// This app is for MacBooks only. Desktop Macs (iMac, Mac mini, Mac Studio, Mac Pro)
/// have no internal battery, so the 20–80 rule is meaningless for them.
enum DeviceGuard {
    struct Report {
        let modelIdentifier: String
        let productName: String?
        let hasInternalBattery: Bool

        var isMacBook: Bool {
            if let name = productName, name.localizedCaseInsensitiveContains("MacBook") { return true }
            if modelIdentifier.localizedCaseInsensitiveContains("MacBook") { return true }
            // Every Apple laptop is a MacBook; every Mac with an internal battery is a laptop.
            return hasInternalBattery
        }

        var displayName: String {
            productName ?? modelIdentifier
        }
    }

    static func inspect() -> Report {
        Report(
            modelIdentifier: sysctlString("hw.model") ?? "Unknown",
            productName: deviceTreeProductName(),
            hasInternalBattery: BatteryMonitor.hasInternalBattery()
        )
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    /// On Apple silicon the marketing name ("MacBook Pro") lives in the device tree.
    private static func deviceTreeProductName() -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let value = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else { return nil }
        if let data = value as? Data {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
        }
        return value as? String
    }
}
