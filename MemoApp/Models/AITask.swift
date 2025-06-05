import Foundation

struct AITask: Identifiable, Hashable {
    var id: UUID = .init()
    var description: String   // タスク内容の説明文
    var suggestedDate: Date?  // AI が「いつまでに」と見積もった場合に設定
} 