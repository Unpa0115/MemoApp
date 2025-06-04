import SwiftData
import Foundation

@Model
// @Observable
class Note {
    @Attribute(.unique) var id: UUID
    var content: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var isDraft: Bool
    
    // タグとの多対多リレーション
    @Relationship var tags: [Tag]
    
    // カテゴリとの多対多リレーション（複数のカテゴリに所属可能）
    @Relationship var categories: [Category]

    init(content: String = "",
         title: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         isDraft: Bool = true,
         tags: [Tag] = [],
         categories: [Category] = []) {
        self.id = UUID()
        self.content = content
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDraft = isDraft
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