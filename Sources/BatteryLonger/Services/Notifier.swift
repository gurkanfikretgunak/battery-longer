import AppKit
import UserNotifications

/// Delivers the one-and-only warning notification for a violation.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// UNUserNotificationCenter crashes outside a real bundle (e.g. `swift run`).
    private var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorization() {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { Log.error("Notification auth failed: \(error.localizedDescription)") }
            Log.info("Notification permission granted: \(granted)")
        }
    }

    func warn(_ violation: Violation, snapshot: BatterySnapshot) {
        if AppSettings.shared.playSound {
            NSSound(named: "Sosumi")?.play()
        }
        guard isAvailable else {
            Log.info("(no bundle) would notify: \(violation.title)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = L("notif.warn.title", violation.title)
        content.subtitle = L("notif.warn.subtitle", snapshot.level)
        content.body = L("notif.warn.body", violation.instruction, Policy.formattedGrace)
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: "bls.warning", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { Log.error("Notification failed: \(error.localizedDescription)") }
        }
    }

    func resolved(_ snapshot: BatterySnapshot) {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["bls.warning"])
        let content = UNMutableNotificationContent()
        content.title = L("notif.resolved.title")
        content.body = L("notif.resolved.body", snapshot.level)
        let request = UNNotificationRequest(identifier: "bls.resolved", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Show banners even while the app is "active" (the popover counts as active).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
