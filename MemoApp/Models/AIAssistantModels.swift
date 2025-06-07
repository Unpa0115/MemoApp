import Foundation

/// アイデアブレインストーミングの候補を表す構造体
struct IdeaSuggestion: Identifiable, Hashable {
    var id: UUID = .init()
    var text: String           // アイデアのテキスト
}

/// 要約生成の種類
enum SummaryType: String, CaseIterable {
    case threeLines = "3行要約"
    case oneParagraph = "1段落要約"
}

/// 要約結果を受け取る構造体
struct SummaryResult {
    var type: SummaryType
    var text: String
}

/// 質問応答モードのやり取り
struct QAItem: Identifiable, Hashable {
    var id: UUID = .init()
    var question: String
    var answer: String
}

/// テンプレート補完の用途選択肢
enum TemplateCategory: String, CaseIterable {
    case taskManagement = "タスク管理"
    case weeklyReview   = "週次振り返り"
    case readingNote    = "読書メモ"
    case meetingNote    = "会議メモ"
    case projectPlan    = "プロジェクト計画"
    
    var displayName: String {
        return rawValue
    }
}

/// テンプレート結果
struct TemplateResult: Identifiable, Hashable {
    var id: UUID = .init()
    var title: String                  // テンプレート名（例：週次振り返り）
    var markdownContent: String        // 生成された Markdown テンプレート
}

/// 翻訳／言い換えリクエストの種類
enum RewriteType: String, CaseIterable {
    case translateEn = "英語翻訳"
    case translateJp = "日本語翻訳"
    case casualToBusiness = "カジュアル→ビジネス"
    case businessToCasual = "ビジネス→カジュアル"
    case formalToFriendly = "フォーマル→フレンドリー"
    
    var displayName: String {
        return rawValue
    }
}

/// リライト結果
struct RewriteResult {
    var original: String
    var rewritten: String
}

/// 品質チェック結果
struct QualityIssue: Identifiable, Hashable {
    var id: UUID = .init()
    var issueDescription: String  // 指摘内容テキスト
    var suggestion: String        // 修正サンプル
    var severity: IssueSeverity   // 問題の重要度
    var category: IssueCategory   // 問題のカテゴリ
}

/// 問題の重要度
enum IssueSeverity: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
}

/// 問題のカテゴリ
enum IssueCategory: String, CaseIterable {
    case grammar = "文法"
    case style = "文体"
    case clarity = "明瞭性"
    case factual = "事実関係"
} 