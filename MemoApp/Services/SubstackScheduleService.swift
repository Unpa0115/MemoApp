import Foundation
import SwiftData
import BackgroundTasks
import UserNotifications

class SubstackScheduleService: ObservableObject {
    private let emailService = EmailService()
    private let backgroundTaskIdentifier = "com.memoapp.substackSend"
    
    /// バックグラウンドタスクの初期化
    func initializeBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleSendTask(task: task as! BGProcessingTask)
        }
    }
    
    /// 予約投稿の作成と通知・バックグラウンドタスクのスケジュール
    func schedulePost(
        _ post: ScheduledPost,
        context: ModelContext
    ) async throws {
        // データベースに保存
        context.insert(post)
        try context.save()
        
        // ローカル通知をスケジュール
        await scheduleLocalNotification(for: post)
        
        // バックグラウンドタスクをスケジュール
        scheduleBackgroundTask(for: post)
    }
    
    /// ローカル通知のスケジュール（投稿5分前）
    private func scheduleLocalNotification(for post: ScheduledPost) async {
        let center = UNUserNotificationCenter.current()
        
        // 通知許可の確認
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            print("通知が許可されていません")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Substack 投稿予約通知"
        content.body = "\(post.title) を \(post.scheduledDate.formatted()) に投稿します。"
        content.sound = .default
        content.userInfo = ["postId": post.id.uuidString]
        
        // 5分前に通知
        let notificationDate = post.scheduledDate.addingTimeInterval(-300)
        guard notificationDate > Date() else { return }
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notificationDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDate,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: post.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("通知をスケジュールしました: \(post.title)")
        } catch {
            print("通知登録エラー: \(error.localizedDescription)")
        }
    }
    
    /// バックグラウンドタスクのスケジュール
    private func scheduleBackgroundTask(for post: ScheduledPost) {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = post.scheduledDate
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("バックグラウンドタスクをスケジュールしました")
        } catch {
            print("BGTaskScheduler 提出エラー: \(error.localizedDescription)")
        }
    }
    
    /// 次回バックグラウンドタスクの再スケジュール
    func scheduleNextBackgroundTask() {
        // 現在時刻以降の最も早い予約を取得
        // 実際にはModelContextを通じて取得する必要がある
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(3600) // 1時間後
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("次回バックグラウンドタスクのスケジュールエラー: \(error.localizedDescription)")
        }
    }
    
    /// バックグラウンドタスクの処理
    private func handleSendTask(task: BGProcessingTask) {
        print("バックグラウンドタスクを開始")
        
        // 次回タスクを再スケジュール
        scheduleNextBackgroundTask()
        
        // 期限切れハンドラーを設定
        task.expirationHandler = {
            print("バックグラウンドタスクが期限切れになりました")
            task.setTaskCompleted(success: false)
        }
        
        // 実際の送信処理を非同期で実行
        Task {
            await processPendingPosts(task: task)
        }
    }
    
    /// 保留中の投稿を処理
    private func processPendingPosts(task: BGProcessingTask) async {
        // ここでModelContextを取得して期限が来た投稿を処理
        // 簡易実装のため、タスク完了のみ
        print("保留中の投稿を処理中...")
        
        // 実際の実装では:
        // 1. ModelContextから期限が来た投稿を取得
        // 2. 各投稿についてメール送信
        // 3. 送信結果をSentLogに記録
        
        task.setTaskCompleted(success: true)
    }
    
    /// 予約投稿のキャンセル
    func cancelScheduledPost(
        _ post: ScheduledPost,
        context: ModelContext
    ) throws {
        // 通知をキャンセル
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [post.id.uuidString]
        )
        
        // データベースから削除
        context.delete(post)
        try context.save()
        
        print("予約投稿をキャンセルしました: \(post.title)")
    }
    
    /// 即座に投稿を送信
    func sendPostImmediately(
        _ post: ScheduledPost,
        context: ModelContext
    ) async -> SentLog {
        let result = await emailService.sendEmail(post: post)
        
        let sentLog: SentLog
        switch result {
        case .success(let url):
            sentLog = SentLog(
                scheduledPost: post,
                substackURL: url,
                success: true
            )
            post.isSent = true
            
        case .failure(let error):
            sentLog = SentLog(
                scheduledPost: post,
                success: false,
                errorMessage: error.localizedDescription
            )
        }
        
        context.insert(sentLog)
        
        do {
            try context.save()
        } catch {
            print("送信ログの保存エラー: \(error.localizedDescription)")
        }
        
        return sentLog
    }
    
    /// 通知許可をリクエスト
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("通知許可のリクエストエラー: \(error.localizedDescription)")
            return false
        }
    }
} 