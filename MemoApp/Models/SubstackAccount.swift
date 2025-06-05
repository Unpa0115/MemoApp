import SwiftData
import Foundation

@Model
class SubstackAccount: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var emailAddress: String            // 例：yourname@substack.com
    var displayName: String?            // 「メイン公開アカウント」などの任意名称
    var createdAt: Date = Date()
    
    init(emailAddress: String, displayName: String? = nil) {
        self.emailAddress = emailAddress
        self.displayName = displayName
    }
} 