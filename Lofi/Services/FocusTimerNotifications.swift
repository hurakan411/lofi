import Foundation
import Combine
import AudioToolbox
import UIKit
import UserNotifications

@MainActor
final class FocusTimerNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var latestSession: FocusSession?
    private var requestingAuthorization = false
    private var generation = UUID()
    override init() {
        super.init()
        center.delegate = self
    }
    func update(session: FocusSession?, requestPermission: Bool = false) {
        latestSession = session
        generation = UUID()
        let token = generation
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return }
        #endif
        if requestPermission, !requestingAuthorization {
            requestingAuthorization=true
            Task {
                if await center.notificationSettings().authorizationStatus == .notDetermined {
                    _ = try? await center.requestAuthorization(options: [.alert, .sound])
                }
                requestingAuthorization=false
                update(session: latestSession)
            }
        }
        Task {
            let status = await center.notificationSettings().authorizationStatus
            guard token == generation else { return }
            let requests = await center.pendingNotificationRequests()
            guard token == generation else { return }
            center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix("lofi.timer.") })
            guard status == .authorized || status == .provisional || status == .ephemeral,
                  let session, session.phase == .running else { return }
            for (index, event) in session.timerEvents(at: Date()).enumerated() {
                guard token == generation else { return }
                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = event.body
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, event.after), repeats: false)
                let request = UNNotificationRequest(identifier: "lofi.timer.\(session.id).\(token).\(index)", content: content, trigger: trigger)
                try? await center.add(request)
                if token != generation { center.removePendingNotificationRequests(withIdentifiers: [request.identifier]) }
            }
        }
    }
    func playBoundaryCue(vibrate: Bool, audio: SoundscapePlayer) {
        if vibrate {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        audio.playChime()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(notification.request.identifier.hasPrefix("lofi.timer.") ? []:[.banner, .sound])
    }
}
