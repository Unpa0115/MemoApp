import SwiftData
import Foundation

@Model
class SMTPService: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serviceName: String             // 例：SendGrid, Mailgun, Amazon SES
    var apiKey: String                  // 各サービスの API キー
    var smtpHost: String                // SMTP ホスト例：smtp.sendgrid.net
    var smtpPort: Int                   // SMTP ポート例：587
    var useTLS: Bool                    // TLS/SSL を使うか
    var fromEmail: String               // 差出人アドレス
    var fromName: String?               // 差出人表示名
    var createdAt: Date = Date()
    
    init(serviceName: String,
         apiKey: String,
         smtpHost: String,
         smtpPort: Int = 587,
         useTLS: Bool = true,
         fromEmail: String,
         fromName: String? = nil) {
        self.serviceName = serviceName
        self.apiKey = apiKey
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.useTLS = useTLS
        self.fromEmail = fromEmail
        self.fromName = fromName
    }
} 