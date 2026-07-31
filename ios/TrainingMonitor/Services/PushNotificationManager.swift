import Combine
import Foundation
import UIKit
import UserNotifications

/// Owns push-notification permission and APNs device-token registration
/// for AI workout reviews (`WorkoutReviewGenerator`). There's no separate
/// on/off flag synced to the backend beyond the registered device token
/// itself — turning reviews off just deletes it there
/// (`PushRegistrationClient.unregister`), so a stale token can't keep
/// triggering silent pushes.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var isEnabled: Bool
    @Published var errorMessage: String?

    private var pendingDeviceToken: String?
    private var athleteID: Int?

    private static let enabledKey = "com.trainingmonitor.app.workout-review-push-enabled"

    private override init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        super.init()
    }

    /// Called once from `AppDelegate` on launch. Re-registers for remote
    /// notifications every cold start when previously enabled, since an
    /// APNs device token can change (e.g. after a device restore) and
    /// Apple's guidance is to re-register on every launch rather than
    /// cache the token indefinitely.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        guard isEnabled else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Called once the athlete's Strava ID is known (`RootView`), so a
    /// device token that arrived before sign-in — or a re-launch after
    /// sign-in — can still reach the backend once there's an athlete to
    /// associate it with.
    func setAthleteID(_ athleteID: Int?) {
        self.athleteID = athleteID
        flushPendingRegistration()
    }

    func enable() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                errorMessage = "Notifications are turned off for this app in iOS Settings."
                return
            }
        } catch {
            errorMessage = "Couldn't request notification permission: \(error.localizedDescription)"
            return
        }

        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        UIApplication.shared.registerForRemoteNotifications()
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        pendingDeviceToken = nil
        if let athleteID {
            Task { await PushRegistrationClient.unregister(athleteID: athleteID) }
        }
    }

    func didRegister(deviceToken: Data) {
        pendingDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        flushPendingRegistration()
    }

    func didFailToRegister(error: Error) {
        errorMessage = "Couldn't register for push notifications: \(error.localizedDescription)"
    }

    private func flushPendingRegistration() {
        guard isEnabled, let athleteID, let pendingDeviceToken else { return }
        Task { await PushRegistrationClient.register(athleteID: athleteID, deviceToken: pendingDeviceToken) }
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Without this, a local notification posted while the app is already
    /// in the foreground (the generator finished while the athlete had
    /// the app open) would be silently swallowed instead of banging.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
