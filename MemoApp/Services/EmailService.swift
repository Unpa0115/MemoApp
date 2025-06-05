import Foundation
import Network
import SwiftData

class EmailService: ObservableObject {
    @Published var isSending = false
    
    private let markdownConverter = MarkdownConverter()
    
    /// メール送信のメインメソッド
    func sendEmail(post: ScheduledPost) async -> Result<URL?, Error> {
        guard !isSending else {
            return .failure(EmailError.alreadySending)
        }
        
        await MainActor.run {
            isSending = true
        }
        
        defer {
            Task { @MainActor in
                isSending = false
            }
        }
        
        do {
            // Markdown → HTML 変換
            let htmlContent = try await convertContentToHTML(post: post)
            
            // メール送信
            let result = try await sendEmailViaSMTP(
                service: post.smtpService,
                to: post.account.emailAddress,
                subject: post.title,
                htmlBody: htmlContent
            )
            
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
    
    /// Markdown コンテンツを HTML に変換
    private func convertContentToHTML(post: ScheduledPost) async throws -> String {
        // キャッシュされたHTMLがあれば使用
        if let cachedHTML = post.contentHTML, !cachedHTML.isEmpty {
            return cachedHTML
        }
        
        // Markdownを基本的なHTMLに変換（後でDownライブラリを使用予定）
        var htmlContent = markdownConverter.convertToHTML(post.contentMarkdown)
        
        // サムネイル画像の挿入
        if let thumbnailData = post.thumbnailData {
            let base64Image = thumbnailData.base64EncodedString()
            let imageTag = "<img src=\"data:image/jpeg;base64,\(base64Image)\" alt=\"サムネイル\" style=\"max-width: 100%; height: auto;\"/><br/>"
            htmlContent = imageTag + htmlContent
        }
        
        // 「続きを読む」リンクの挿入
        if post.includeReadMore {
            htmlContent += "<hr><p><a href=\"#\">続きを読む</a></p>"
        }
        
        return htmlContent
    }
    
    /// SMTP経由でメール送信
    private func sendEmailViaSMTP(
        service: SMTPService,
        to: String,
        subject: String,
        htmlBody: String
    ) async throws -> URL? {
        
        // 実際のSMTP送信実装（簡易版）
        // 本格実装では SendGrid SDK や Swift-SMTP ライブラリを使用
        
        switch service.serviceName.lowercased() {
        case "sendgrid":
            return try await sendViaSendGrid(service: service, to: to, subject: subject, htmlBody: htmlBody)
        case "mailgun":
            return try await sendViaMailgun(service: service, to: to, subject: subject, htmlBody: htmlBody)
        default:
            throw EmailError.unsupportedService(service.serviceName)
        }
    }
    
    /// SendGrid API経由での送信
    private func sendViaSendGrid(
        service: SMTPService,
        to: String,
        subject: String,
        htmlBody: String
    ) async throws -> URL? {
        
        let url = URL(string: "https://api.sendgrid.com/v3/mail/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(service.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let emailData: [String: Any] = [
            "personalizations": [
                [
                    "to": [["email": to]],
                    "subject": subject
                ]
            ],
            "from": [
                "email": service.fromEmail,
                "name": service.fromName ?? service.fromEmail
            ],
            "content": [
                [
                    "type": "text/html",
                    "value": htmlBody
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            // 成功 - Substack側の処理を待つ必要があるため、仮のURLを返す
            return URL(string: "https://\(to.replacingOccurrences(of: "@", with: ".")).substack.com/")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "不明なエラー"
            throw EmailError.sendingFailed(errorMessage)
        }
    }
    
    /// Mailgun API経由での送信
    private func sendViaMailgun(
        service: SMTPService,
        to: String,
        subject: String,
        htmlBody: String
    ) async throws -> URL? {
        
        // Mailgun実装は簡略化
        // 実際にはドメイン設定などが必要
        throw EmailError.notImplemented("Mailgun送信はまだ実装されていません")
    }
}

// MARK: - エラー定義
enum EmailError: LocalizedError {
    case alreadySending
    case unsupportedService(String)
    case invalidResponse
    case sendingFailed(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadySending:
            return "すでに送信処理中です"
        case .unsupportedService(let service):
            return "サポートされていないサービス: \(service)"
        case .invalidResponse:
            return "無効なレスポンスを受信しました"
        case .sendingFailed(let message):
            return "送信に失敗しました: \(message)"
        case .notImplemented(let message):
            return message
        }
    }
}

// MARK: - Markdown変換用のヘルパークラス
class MarkdownConverter {
    /// 基本的なMarkdown → HTML変換
    /// 実際にはDownライブラリを使用することを推奨
    func convertToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // 基本的な変換規則（簡易版）
        html = html.replacingOccurrences(
            of: #"^# (.+)$"#,
            with: "<h1>$1</h1>",
            options: [.regularExpression]
        )
        
        html = html.replacingOccurrences(
            of: #"^## (.+)$"#,
            with: "<h2>$1</h2>",
            options: [.regularExpression]
        )
        
        html = html.replacingOccurrences(
            of: #"^### (.+)$"#,
            with: "<h3>$1</h3>",
            options: [.regularExpression]
        )
        
        html = html.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        
        html = html.replacingOccurrences(
            of: #"\*(.+?)\*"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        
        // 改行をHTMLの段落に変換
        let paragraphs = html.components(separatedBy: "\n\n")
        html = paragraphs.map { paragraph in
            if paragraph.hasPrefix("<h") || paragraph.isEmpty {
                return paragraph
            } else {
                return "<p>" + paragraph.replacingOccurrences(of: "\n", with: "<br/>") + "</p>"
            }
        }.joined(separator: "\n")
        
        return html
    }
} 