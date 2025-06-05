import SwiftData
import Foundation

/// 目標とメモの自動連携を管理するサービス
class GoalAutoLinkService {
    static let shared = GoalAutoLinkService()
    
    private init() {}
    
    /// メモ作成時に呼び出して、該当する目標に自動連携させる
    func autoLinkNoteToGoals(_ note: Note, context: ModelContext) {
        do {
            // 全ての目標を取得
            let descriptor = FetchDescriptor<Goal>()
            let goals = try context.fetch(descriptor)
            
            // 各目標に対してメモを自動連携チェック
            for goal in goals {
                goal.autoLinkNote(note, context: context)
            }
            
            // 変更を保存
            try context.save()
            
            print("メモ '\(note.title ?? "無題")' を目標に自動連携しました")
            
        } catch {
            print("目標自動連携エラー: \(error.localizedDescription)")
        }
    }
} 