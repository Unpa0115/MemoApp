import UserNotifications
import Foundation

class ReminderService: ObservableObject {
    static let shared = ReminderService()
    
    private init() {}
    
    // メモ保存時 or 更新時に呼び出す
    func scheduleReminderIfNeeded(for note: Note) {
        guard note.hasReminder == true, let date = note.reminderDate else {
            removePendingReminder(for: note)
            return
        }
        
        // 過去の日時は設定しない
        guard date > Date() else {
            print("過去の日時にはリマインダーを設定できません")
            return
        }
        
        // 通知許可がない場合はリクエスト
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    self.requestNotificationAuthorization { granted in
                        if granted {
                            self.createNotificationRequest(for: note, at: date)
                        } else {
                            // ユーザーに許可を促すアラートを表示（UIスレッド）
                            print("通知許可が拒否されました")
                        }
                    }
                } else if settings.authorizationStatus == .authorized {
                    self.createNotificationRequest(for: note, at: date)
                } else {
                    // 許可が拒否されている場合、ユーザーに設定を促す
                    print("通知許可が必要です。設定から許可してください。")
                }
            }
        }
    }
    
    // 通知許可をリクエスト
    func requestNotificationAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // 通知リクエストの作成
    private func createNotificationRequest(for note: Note, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = note.title ?? "リマインダー"
        content.body = "「\(note.title ?? "メモ")」のリマインダーです。"
        content.sound = .default
        
        // カスタム userInfo にメモIDを付与
        content.userInfo = ["noteID": note.id.uuidString]
        
        // 指定日時に送信
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: note.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("リマインダーを設定しました: \(date)")
            }
        }
    }
    
    // リマインダー解除（memo.hasReminder == false のときや、日付変更時）
    func removePendingReminder(for note: Note) {
        if note.hasReminder != true {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [note.id.uuidString]
            )
        }
    }
    
    // タスクごとのリマインダー登録
    func scheduleTaskReminder(_ task: AITask, for note: Note, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "タスクリマインダー"
        content.body = task.description
        content.sound = .default
        // userInfo に noteID と taskID を格納
        content.userInfo = ["noteID": note.id.uuidString, "taskID": task.id.uuidString]
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(note.id.uuidString)-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("タスクリマインダー登録失敗: \(error.localizedDescription)")
            } else {
                print("タスクリマインダーを設定しました: \(task.description)")
            }
        }
    }
} 
