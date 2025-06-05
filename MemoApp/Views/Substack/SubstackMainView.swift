import SwiftUI
import SwiftData
import UserNotifications

struct SubstackMainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scheduleService = SubstackScheduleService()
    
    @Query private var accounts: [SubstackAccount]
    @Query private var services: [SMTPService]
    @Query(filter: #Predicate<ScheduledPost> { !$0.isSent }, sort: \ScheduledPost.scheduledDate)
    private var pendingPosts: [ScheduledPost]
    @Query(filter: #Predicate<SentLog> { $0.success }, sort: \SentLog.sentDate, order: .reverse)
    private var recentSuccessfulSends: [SentLog]
    
    @State private var showingNewPostForm = false
    @State private var notificationPermissionGranted = false
    
    var body: some View {
        NavigationStack {
            List {
                // 概要セクション
                Section("概要") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("予約中")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pendingPosts.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("送信成功")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(recentSuccessfulSends.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 次回予約投稿
                if let nextPost = pendingPosts.first {
                    Section("次の予約投稿") {
                        NextPostRow(post: nextPost)
                    }
                }
                
                // クイックアクション
                Section("投稿") {
                    Button(action: { showingNewPostForm = true }) {
                        Label("新規投稿を作成", systemImage: "plus.circle.fill")
                    }
                    .disabled(accounts.isEmpty || services.isEmpty)
                    
                    if accounts.isEmpty || services.isEmpty {
                        Text("投稿するにはアカウントとSMTPサービスの設定が必要です")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 管理セクション
                Section("管理") {
                    NavigationLink(destination: ScheduledPostListView()) {
                        Label("予約投稿一覧", systemImage: "calendar")
                    }
                    
                    NavigationLink(destination: SentLogListView()) {
                        Label("送信ログ", systemImage: "list.bullet.clipboard")
                    }
                }
                
                // 設定セクション
                Section("設定") {
                    NavigationLink(destination: SubstackAccountListView()) {
                        Label("Substackアカウント", systemImage: "person.circle")
                    }
                    
                    NavigationLink(destination: SMTPServiceListView()) {
                        Label("SMTPサービス", systemImage: "envelope.circle")
                    }
                    
                    HStack {
                        Label("通知許可", systemImage: "bell.circle")
                        Spacer()
                        Image(systemName: notificationPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationPermissionGranted ? .green : .red)
                    }
                }
            }
            .navigationTitle("Substack")
            .onAppear {
                checkNotificationPermission()
            }
            .sheet(isPresented: $showingNewPostForm) {
                ScheduledPostFormView()
            }
        }
    }
    
    private func checkNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationPermissionGranted = settings.authorizationStatus == .authorized
            }
            
            // 許可されていない場合は要求
            if settings.authorizationStatus == .notDetermined {
                let granted = await scheduleService.requestNotificationPermission()
                await MainActor.run {
                    notificationPermissionGranted = granted
                }
            }
        }
    }
}

struct NextPostRow: View {
    let post: ScheduledPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.title)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text(post.account.displayName ?? post.account.emailAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(timeUntilPost)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Text("予定: \(post.scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private var timeUntilPost: String {
        let now = Date()
        let interval = post.scheduledDate.timeIntervalSince(now)
        
        if interval <= 0 {
            return "送信予定時刻を過ぎています"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)日後"
        } else if hours > 0 {
            return "\(hours)時間\(minutes > 0 ? "\(minutes)分" : "")後"
        } else {
            return "\(minutes)分後"
        }
    }
}

// 一時的なプレースホルダービュー（後で実装）
struct ScheduledPostListView: View {
    var body: some View {
        Text("予約投稿一覧画面")
            .navigationTitle("予約投稿")
    }
}

struct SentLogListView: View {
    var body: some View {
        Text("送信ログ画面")
            .navigationTitle("送信ログ")
    }
}

#Preview {
    SubstackMainView()
        .modelContainer(for: [SubstackAccount.self, SMTPService.self, ScheduledPost.self, SentLog.self], inMemory: true)
} 