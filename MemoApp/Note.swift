import SwiftData
import Foundation

@Model
class Note: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var content: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var isDraft: Bool
    
    // ── リマインダー機能用プロパティ ──
    var reminderDate: Date?            // ユーザーが設定したリマインダー日時
    var hasReminder: Bool?             // リマインダー設定フラグ
    // AI タスク抽出用に、一時的に生成されたタスクを保持する配列
    @Transient var aiSuggestedTasks: [AITask] = []
    
    // タグとの多対多リレーション
    @Relationship var tags: [Tag]
    
    // カテゴリとの多対多リレーション（複数のカテゴリに所属可能）
    @Relationship var categories: [Category]

    init(content: String = "",
         title: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         isDraft: Bool = true,
         reminderDate: Date? = nil,
         hasReminder: Bool? = false,
         tags: [Tag] = [],
         categories: [Category] = []) {
        self.id = UUID()
        self.content = content
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDraft = isDraft
        self.reminderDate = reminderDate
        self.hasReminder = hasReminder
        self.tags = tags
        self.categories = categories
    }

    /// 先頭行からタイトルを自動抽出
    func extractTitle() {
        let lines = content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        if let firstLine = lines.first {
            if firstLine.starts(with: "# ") {
                title = String(firstLine.dropFirst(2))
            } else {
                let raw = String(firstLine)
                if raw.count > 20 {
                    let idx = raw.index(raw.startIndex, offsetBy: 20)
                    title = String(raw[...idx]) + "…"
                } else {
                    title = raw
                }
            }
        } else {
            title = "（無題）"
        }
    }
} 