import UIKit

/// Thin UIKit shim for the APNs callbacks SwiftUI's `App` protocol doesn't
/// expose directly — registered via `@UIApplicationDelegateAdaptor` in
/// `TrainingMonitorApp`. All the actual push-notification state and logic
/// lives in `PushNotificationManager` and `WorkoutReviewGenerator`; this
/// class only forwards.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task { @MainActor in PushNotificationManager.shared.configure() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushNotificationManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushNotificationManager.shared.didFailToRegister(error: error) }
    }

    /// A silent (`content-available`) push from the backend's Strava
    /// webhook handler telling us a new activity just synced — see
    /// `backend/src/routes/webhooks.ts`. Runs in the background whether
    /// the app is foregrounded, backgrounded, or was launched fresh for
    /// this delivery.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard
            userInfo["type"] as? String == "workout-review",
            let activityID = userInfo["activityId"] as? Int
        else {
            completionHandler(.noData)
            return
        }

        Task {
            await WorkoutReviewGenerator.run(activityID: activityID)
            completionHandler(.newData)
        }
    }
}
