import SwiftData
import Foundation

@Model
class Goal: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String           // 例：「毎日ブログを書く」「週3回筋トレ」
    var frequency: Frequency   // .daily, .weekly, .monthly など
    var targetCount: Int       // 週間なら 3（回）、日次なら 1（回）など
    var startDate: Date        // 目標開始日
    var createdAt: Date
    // 進捗を管理するタスク（関連 Note の ID と実行日時を記録）
    @Relationship(deleteRule: .cascade) var linkedNotes: [LinkedNote]

    init(name: String,
         frequency: Frequency,
         targetCount: Int,
         startDate: Date = .now) {
        self.id = UUID()
        self.name = name
        self.frequency = frequency
        self.targetCount = targetCount
        self.startDate = startDate
        self.createdAt = .now
        self.linkedNotes = []
    }
    
    /// 今の周期における達成数を返す
    var currentPeriodProgress: Double {
        let now = Date()
        let calendar = Calendar.current
        let lowerBound: Date
        switch frequency {
        case .daily:
            lowerBound = calendar.startOfDay(for: now) // 今日 00:00
        case .weekly:
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = weekday - 2 // 月曜を 0 とするため
            let monday = calendar.date(
                byAdding: .day,
                value: -daysFromMonday,
                to: now
            ) ?? now
            lowerBound = calendar.startOfDay(for: monday)
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: comps) ?? now
            lowerBound = startOfMonth
        }
        let count = linkedNotes.filter { $0.linkedDate >= lowerBound }.count
        return min(Double(count) / Double(targetCount), 1.0)
    }

    /// 連続日数を算出（デイリー目標の場合のみ有効）
    var consecutiveDays: Int {
        guard frequency == .daily else { return 0 }
        let calendar = Calendar.current
        var count = 0
        var checkDate = calendar.startOfDay(for: Date())
        while true {
            if linkedNotes.contains(where: {
                calendar.isDate($0.linkedDate, inSameDayAs: checkDate)
            }) {
                count += 1
                // 昨日にずらす
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return count
    }
    
    /// 指定された日付がこの目標の対象期間内かどうかを判定
    func isDateInTargetPeriod(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // 開始日以降かチェック
        guard date >= startDate else { return false }
        
        switch frequency {
        case .daily:
            // 日次目標：メモの作成日が今日なら対象
            return calendar.isDate(date, inSameDayAs: now)
        case .weekly:
            // 週次目標：メモの作成日が今週なら対象
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = weekday - 2 // 月曜を 0 とするため
            let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) ?? now
            let lowerBound = calendar.startOfDay(for: monday)
            return date >= lowerBound
        case .monthly:
            // 月次目標：メモの作成日が今月なら対象
            let comps = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: comps) ?? now
            return date >= startOfMonth
        }
    }
    
    /// メモを自動的にこの目標に紐付ける
    func autoLinkNote(_ note: Note, context: ModelContext) {
        // 既に同じメモが紐づけられているかチェック
        guard !linkedNotes.contains(where: { $0.noteId == note.id }) else { return }
        
        // この目標の対象期間内かチェック
        guard isDateInTargetPeriod(note.createdAt) else { return }
        
        // 新しいLinkedNoteを作成
        let linkedNote = LinkedNote(goal: self, noteId: note.id, linkedDate: note.createdAt)
        context.insert(linkedNote)
    }
}

@Model
class LinkedNote: Identifiable {
    @Attribute(.unique) var id: UUID
    @Relationship(inverse: \Goal.linkedNotes) var goal: Goal?
    var noteId: UUID       // Note への参照（直接リレーションだとループが発生する可能性があるため UUID で参照）
    var linkedDate: Date       // メモ作成 or タスク完了日時
    
    init(goal: Goal, noteId: UUID, linkedDate: Date = .now) {
        self.id = UUID()
        self.goal = goal
        self.noteId = noteId
        self.linkedDate = linkedDate
    }
}

enum Frequency: String, Codable, CaseIterable {
    case daily = "日次"
    case weekly = "週次"
    case monthly = "月次"
} 