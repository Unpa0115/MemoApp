import SwiftData
import Foundation

@Model
class SentLog: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var scheduledPost: ScheduledPost?
    var sentDate: Date                   // 実際に送信した日時
    var substackURL: URL?                // Substack に反映された公開 URL
    var success: Bool                    // 送信成功/失敗
    var errorMessage: String?            // 失敗時のエラーメッセージ
    
    init(scheduledPost: ScheduledPost? = nil,
         sentDate: Date = Date(),
         substackURL: URL? = nil,
         success: Bool,
         errorMessage: String? = nil) {
        self.scheduledPost = scheduledPost
        self.sentDate = sentDate
        self.substackURL = substackURL
        self.success = success
        self.errorMessage = errorMessage
    }
} 