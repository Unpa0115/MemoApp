import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 通知タップ時（バックグラウンド／フォアグラウンド問わず呼ばれる）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let noteIDString = userInfo["noteID"] as? String,
           let noteID = UUID(uuidString: noteIDString) {
            // メインスレッドで画面遷移
            await MainActor.run {
                // 例: Global Navigation Stack を使い NoteEditorView(noteID:) へ遷移
                NotificationCenter.default.post(
                    name: .didReceiveNoteNotification,
                    object: nil,
                    userInfo: ["noteID": noteID, "taskID": userInfo["taskID"] as Any]
                )
            }
        }
    }
    
    // フォアグラウンドで通知を受信した場合の処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
}

extension Notification.Name {
    static let didReceiveNoteNotification = Notification.Name("didReceiveNoteNotification")
} 