import SwiftData
import Foundation

@Model
class ScheduledPost: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var account: SubstackAccount
    var smtpService: SMTPService
    var title: String                    // 投稿タイトル
    var contentMarkdown: String          // 本文（Markdown形式）
    var contentHTML: String?             // 変換後のHTML（キャッシュ用）
    var thumbnailData: Data?             // サムネイル画像を Data で保存
    var includeReadMore: Bool            // 「続きを読む」リンクを挿入するか
    var scheduledDate: Date              // 送信予約日時
    var createdAt: Date                  // 予約作成日時
    var isSent: Bool                     // 送信済みフラグ
    
    init(account: SubstackAccount,
         smtpService: SMTPService,
         title: String,
         contentMarkdown: String,
         includeReadMore: Bool,
         scheduledDate: Date) {
        self.account = account
        self.smtpService = smtpService
        self.title = title
        self.contentMarkdown = contentMarkdown
        self.includeReadMore = includeReadMore
        self.scheduledDate = scheduledDate
        self.createdAt = Date()
        self.isSent = false
    }
} 