import Foundation

/// エラー種別
enum AIClientError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case apiKeyMissing
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .requestFailed(let error):
            return "リクエストが失敗しました: \(error.localizedDescription)"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .decodingFailed(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .apiKeyMissing:
            return "APIキーが設定されていません"
        case .networkUnavailable:
            return "ネットワークに接続できません"
        }
    }
}

/// OpenAI などのエンドポイント設定
struct AIConfig {
    static var apiKey: String {
        // Keychainから取得を優先し、フォールバックとして環境変数を使用
        if let keychainKey = KeychainService.shared.getOpenAIKey(), !keychainKey.isEmpty {
            return keychainKey
        }
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    static let baseURL = "https://api.openai.com/v1"
    static let model = "gpt-3.5-turbo"
}

/// 共通HTTPメソッド
enum HTTPMethod: String {
    case GET, POST
}

/// OpenAI API用のリクエスト・レスポンス構造体
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: ChatMessage
    }
}

/// 共通APIクライアント
@MainActor
class AIClient: ObservableObject {
    static let shared = AIClient()
    
    private init() {}
    
    /// OpenAI ChatCompletion APIを呼び出す汎用メソッド
    private func chatCompletion(
        messages: [ChatMessage],
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) async throws -> String {
        guard !AIConfig.apiKey.isEmpty else {
            throw AIClientError.apiKeyMissing
        }
        
        guard let url = URL(string: "\(AIConfig.baseURL)/chat/completions") else {
            throw AIClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.setValue("Bearer \(AIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // シミュレータではより短いタイムアウトを設定
        #if targetEnvironment(simulator)
        request.timeoutInterval = 15.0
        #else
        request.timeoutInterval = 30.0
        #endif
        
        let requestBody = ChatCompletionRequest(
            model: AIConfig.model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        print("🚀 APIリクエスト送信中...")
        print("📊 リクエストサイズ: \(request.httpBody?.count ?? 0) bytes")
        
        let (data, response): (Data, URLResponse)
        do {
            let startTime = Date()
            (data, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            print("⏱️ レスポンス受信時間: \(String(format: "%.2f", duration))秒")
            print("📦 レスポンスサイズ: \(data.count) bytes")
        } catch {
            print("💥 ネットワークリクエスト失敗: \(error)")
            throw AIClientError.requestFailed(error)
        }
        
        guard let httpRes = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        
        // HTTPステータスコードが200番台でない場合の詳細なエラー処理
        if !(200...299).contains(httpRes.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("API Error - Status Code: \(httpRes.statusCode)")
            print("API Error - Response: \(errorMessage)")
            
            // OpenAI API特有のエラーレスポンスをパース
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIClientError.requestFailed(NSError(domain: "OpenAIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
            } else {
                throw AIClientError.requestFailed(NSError(domain: "HTTPError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpRes.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpRes.statusCode))"]))
            }
        }
        
        let decoder = JSONDecoder()
        do {
            let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
            return chatResponse.choices.first?.message.content ?? ""
        } catch {
            throw AIClientError.decodingFailed(error)
        }
    }
    
    /// APIキーの有効性をテストする軽量なメソッド（詳細ログ付き）
    func testAPIKey() async throws {
        print("🔍 APIキー検証開始")
        print("🔑 使用するAPIキー: \(AIConfig.apiKey.prefix(10))...")
        print("🌐 ターゲットURL: \(AIConfig.baseURL)/chat/completions")
        print("📱 実行環境: \(targetEnvironment())")
        
        do {
            let testMessage = [ChatMessage(role: "user", content: "Hello")]
            let response = try await chatCompletion(messages: testMessage, maxTokens: 1)
            print("✅ APIキー検証成功: \(response)")
        } catch {
            print("❌ APIキー検証失敗: \(error)")
            print("❌ エラー詳細: \(error.localizedDescription)")
            
            // エラーの種類を詳細に分析
            if let urlError = error as? URLError {
                print("🔍 URLError詳細:")
                print("  - コード: \(urlError.code.rawValue)")
                print("  - 説明: \(urlError.localizedDescription)")
                if #available(iOS 18.4, *) {
                    print("  - URL: \(urlError.failingURL?.absoluteString ?? "不明")")
                } else {
                    print("  - URL: \(urlError.failureURLString ?? "不明")")
                }
            }
            
            throw error
        }
    }
    
    /// 実行環境を取得
    private func targetEnvironment() -> String {
        #if targetEnvironment(simulator)
        return "シミュレータ"
        #else
        return "実機"
        #endif
    }
    
    /// ネットワーク接続のテスト（シミュレータ対応）
    func testNetworkConnection() async -> Bool {
        // シミュレータではより軽量なテストを実行
        #if targetEnvironment(simulator)
        return await testSimulatorNetworkConnection()
        #else
        return await testRealDeviceNetworkConnection()
        #endif
    }
    
    /// シミュレータ用のネットワーク接続テスト
    private func testSimulatorNetworkConnection() async -> Bool {
        // シミュレータでは Google DNS を使用した軽量テスト
        guard let url = URL(string: "https://8.8.8.8") else { return false }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0  // 短いタイムアウト
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 シミュレータ ネットワーク接続テスト - Status: \(httpResponse.statusCode)")
                return true  // 接続できれば成功とみなす
            }
        } catch {
            print("🌐 シミュレータ ネットワーク接続テスト失敗: \(error)")
            // シミュレータでは接続テストの失敗を無視し、警告のみ表示
            print("⚠️ シミュレータでのネットワーク接続テストをスキップします")
            return true  // シミュレータでは常に成功として扱う
        }
        
        return true
    }
    
    /// 実機用のネットワーク接続テスト
    private func testRealDeviceNetworkConnection() async -> Bool {
        guard let url = URL(string: "https://api.openai.com") else { return false }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 ネットワーク接続テスト - Status: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200 || httpResponse.statusCode == 404
            }
        } catch {
            print("🌐 ネットワーク接続テスト失敗: \(error)")
        }
        
        return false
    }
    
    // MARK: - サブ機能別APIメソッド
    
    /// アイデアブレインストーミング
    func fetchIdeaSuggestions(
        theme: String,
        keywords: String
    ) async throws -> [IdeaSuggestion] {
        let prompt = """
        テーマ: \(theme)
        キーワード: \(keywords)
        
        上記のテーマとキーワードに基づいて、5つの創造的なアイデアを日本語で提案してください。
        各アイデアは1行で簡潔に表現してください。
        アイデアのみを番号なしで、改行区切りで出力してください。
        """
        
        let messages = [ChatMessage(role: "user", content: prompt)]
        let response = try await chatCompletion(messages: messages, temperature: 0.8)
        
        let ideas = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { IdeaSuggestion(text: $0) }
        
        return ideas
    }
    
    /// サマリー（要約）生成
    func fetchSummary(
        content: String,
        type: SummaryType
    ) async throws -> SummaryResult {
        let instruction = switch type {
        case .threeLines:
            "以下のテキストを3行で要約してください："
        case .oneParagraph:
            "以下のテキストを1段落で要約してください："
        }
        
        let prompt = "\(instruction)\n\n\(content)"
        let messages = [ChatMessage(role: "user", content: prompt)]
        let summary = try await chatCompletion(messages: messages, temperature: 0.3)
        
        return SummaryResult(type: type, text: summary)
    }
    
    /// 質問／応答 Q&A
    func fetchQAResponse(
        content: String,
        question: String
    ) async throws -> String {
        let prompt = """
        以下のテキストに基づいて質問に答えてください：
        
        テキスト:
        \(content)
        
        質問: \(question)
        """
        
        let messages = [ChatMessage(role: "user", content: prompt)]
        return try await chatCompletion(messages: messages, temperature: 0.5)
    }
    
    /// テンプレート補完
    func fetchTemplate(
        category: TemplateCategory
    ) async throws -> TemplateResult {
        let prompt = switch category {
        case .taskManagement:
            "タスク管理用のMarkdownテンプレートを作成してください。見出し、優先度、期限、進捗状況を含む構造を提案してください。"
        case .weeklyReview:
            "週次振り返り用のMarkdownテンプレートを作成してください。今週の成果、課題、来週の目標を含む構造を提案してください。"
        case .readingNote:
            "読書メモ用のMarkdownテンプレートを作成してください。本の情報、要約、感想、引用を含む構造を提案してください。"
        case .meetingNote:
            "会議メモ用のMarkdownテンプレートを作成してください。参加者、議題、決定事項、アクションアイテムを含む構造を提案してください。"
        case .projectPlan:
            "プロジェクト計画用のMarkdownテンプレートを作成してください。目標、スケジュール、リソース、リスクを含む構造を提案してください。"
        }
        
        let messages = [ChatMessage(role: "user", content: prompt)]
        let markdown = try await chatCompletion(messages: messages, temperature: 0.4)
        
        return TemplateResult(title: category.displayName, markdownContent: markdown)
    }
    
    /// 翻訳・言い換え
    func fetchRewrite(
        original: String,
        type: RewriteType
    ) async throws -> RewriteResult {
        let prompt = switch type {
        case .translateEn:
            "以下の日本語テキストを自然な英語に翻訳してください：\n\n\(original)"
        case .translateJp:
            "以下の英語テキストを自然な日本語に翻訳してください：\n\n\(original)"
        case .casualToBusiness:
            "以下のカジュアルなテキストをビジネス調に書き換えてください：\n\n\(original)"
        case .businessToCasual:
            "以下のビジネス調のテキストをカジュアルに書き換えてください：\n\n\(original)"
        case .formalToFriendly:
            "以下のフォーマルなテキストをフレンドリーな調子に書き換えてください：\n\n\(original)"
        }
        
        let messages = [ChatMessage(role: "user", content: prompt)]
        let rewritten = try await chatCompletion(messages: messages, temperature: 0.5)
        
        return RewriteResult(original: original, rewritten: rewritten)
    }
    
    /// 品質チェック・リライトサポート
    func fetchQualityIssues(
        text: String
    ) async throws -> [QualityIssue] {
        let prompt = """
        以下のテキストの品質をチェックし、文法、文体、明瞭性、事実関係の観点から問題点と修正案を提示してください。
        各問題について、以下の形式で出力してください：
        
        [問題] 問題の説明
        [修正案] 修正案
        [重要度] 低/中/高
        [カテゴリ] 文法/文体/明瞭性/事実関係
        ---
        
        テキスト:
        \(text)
        """
        
        let messages = [ChatMessage(role: "user", content: prompt)]
        let response = try await chatCompletion(messages: messages, temperature: 0.3)
        
        // レスポンスをパースしてQualityIssueの配列に変換
        let issues = parseQualityIssues(from: response)
        return issues
    }
    
    /// 品質チェックのレスポンスをパースするヘルパーメソッド
    private func parseQualityIssues(from response: String) -> [QualityIssue] {
        let sections = response.components(separatedBy: "---")
        var issues: [QualityIssue] = []
        
        for section in sections {
            let lines = section.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            var issueDescription = ""
            var suggestion = ""
            var severity = IssueSeverity.medium
            var category = IssueCategory.grammar
            
            for line in lines {
                if line.hasPrefix("[問題]") {
                    issueDescription = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("[修正案]") {
                    suggestion = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("[重要度]") {
                    let severityText = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    severity = IssueSeverity.allCases.first { $0.rawValue == severityText } ?? .medium
                } else if line.hasPrefix("[カテゴリ]") {
                    let categoryText = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    category = IssueCategory.allCases.first { $0.rawValue == categoryText } ?? .grammar
                }
            }
            
            if !issueDescription.isEmpty && !suggestion.isEmpty {
                issues.append(QualityIssue(
                    issueDescription: issueDescription,
                    suggestion: suggestion,
                    severity: severity,
                    category: category
                ))
            }
        }
        
        return issues
    }
} 