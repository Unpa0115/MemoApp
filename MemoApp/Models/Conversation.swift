import SwiftData
import Foundation

/// 会話全体を表すモデル。複数のメッセージを持つ。
@Model
class Conversation: Identifiable {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var messages: [Message]
    
    init() {
        self.id = UUID()
        self.createdAt = Date.now
        self.messages = []
    }
}

/// 個々のメッセージを表すモデル
@Model
class Message: Identifiable {
    @Attribute(.unique) var id: UUID
    var role: Role              // .user または .assistant
    var content: String         // 発言テキスト（Markdown もしくはプレーンテキスト）
    var createdAt: Date  // メッセージ生成日時

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date.now
    }
}

/// メッセージの役割（ユーザー or AI）
enum Role: String, Codable {
    case user = "user"
    case assistant = "assistant"
} 