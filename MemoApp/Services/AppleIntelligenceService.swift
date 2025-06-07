import Foundation
import UIKit
import SwiftUI

/// Apple Intelligence Writing Tools使用案内サービス
/// 
/// **重要:** Writing ToolsはUIKit/SwiftUIに組み込み済み
/// TextEditorでテキスト選択→Writing Toolsアイコンで利用
@MainActor
class AppleIntelligenceService: ObservableObject {
    static let shared = AppleIntelligenceService()
    
    private init() {}
    
    /// Apple Intelligence Writing Toolsが利用可能かチェック
    var isAvailable: Bool {
        if #available(iOS 18.1, *) {
            return true // 基本的な機能は利用可能
        }
        return false
    }
    
    /// Writing Tools使用案内テキスト
    func getWritingToolsInstructions() -> String {
        return """
        📝 Apple Intelligence Writing Toolsの使用方法:
        
        1. メモエディターで文章を選択
        2. 表示されるWriting Toolsアイコンをタップ
        3. 校正・要約・書き換えから選択
        
        ※ iOS 18.1以降、対応デバイスで自動利用可能
        """
    }
    
    /// Apple Intelligence対応状況の説明
    var statusDescription: String {
        if isAvailable {
            return "利用可能 - メモエディターでテキストを選択してご利用ください"
        } else {
            return "iOS 18.1以降、対応デバイスで利用可能"
        }
    }
} 