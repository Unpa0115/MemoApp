import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal
    @State private var showNotePicker = false
    @State private var selectedNotes: [Note] = []
    @State private var showingEditForm = false
    @Query private var allNotes: [Note]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 目標情報表示
                VStack(alignment: .leading, spacing: 12) {
                    Text(goal.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("周期:")
                        Text(goal.frequency.rawValue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(6)
                    }
                    .font(.subheadline)
                    
                    Text("開始日: \(goal.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 進捗バー
                VStack(alignment: .leading, spacing: 8) {
                    Text("進捗状況")
                        .font(.headline)
                    
                    HStack {
                        Text("進捗:")
                        ProgressView(value: goal.currentPeriodProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("\(Int(goal.currentPeriodProgress * 100))%")
                            .font(.caption)
                    }
                    
                    Text("目標: \(goal.linkedNotes.filter { isInCurrentPeriod($0.linkedDate) }.count) / \(goal.targetCount) 回")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 連続日数
                if goal.frequency == .daily {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("継続状況")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("連続日数: \(goal.consecutiveDays) 日")
                                .font(.subheadline)
                        }
                    }
                    
                    Divider()
                }
                
                // タスク紐付けボタン
                Button(action: { showNotePicker.toggle() }) {
                    Label("タスクを紐づけて完了とみなす", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // 達成済みタスク一覧
                VStack(alignment: .leading, spacing: 8) {
                    Text("達成タスク一覧")
                        .font(.headline)
                    
                    if goal.linkedNotes.isEmpty {
                        Text("まだタスクが紐づけられていません")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(goal.linkedNotes.sorted(by: { $0.linkedDate > $1.linkedDate })) { linkedNote in
                                LinkedNoteRowView(linkedNote: linkedNote, allNotes: allNotes)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("目標詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編集") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showNotePicker) {
            NotePickerView(selectedNotes: $selectedNotes, goal: goal)
                .onDisappear {
                    linkNotesToGoal()
                }
        }
        .sheet(isPresented: $showingEditForm) {
            GoalFormView(goal: goal)
        }
    }
    
    // 現在の周期内かチェック
    private func isInCurrentPeriod(_ date: Date) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        switch goal.frequency {
        case .daily:
            return calendar.isDate(date, inSameDayAs: now)
        case .weekly:
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = weekday - 2
            let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) ?? now
            let lowerBound = calendar.startOfDay(for: monday)
            return date >= lowerBound
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: comps) ?? now
            return date >= startOfMonth
        }
    }
    
    // メモ選択後に呼ばれるメソッド
    private func linkNotesToGoal() {
        for note in selectedNotes {
            let ln = LinkedNote(goal: goal, noteId: note.id, linkedDate: .now)
            context.insert(ln)
        }
        do {
            try context.save()
            selectedNotes.removeAll()
        } catch {
            print("リンク保存エラー: \(error.localizedDescription)")
        }
    }
}

struct LinkedNoteRowView: View {
    let linkedNote: LinkedNote
    let allNotes: [Note]
    
    var note: Note? {
        allNotes.first { $0.id == linkedNote.noteId }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("- \(note?.title ?? "（削除されたメモ）")")
                    .font(.subheadline)
                Text(linkedNote.linkedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let goal = Goal(name: "毎日ブログを書く", frequency: .daily, targetCount: 1)
    return GoalDetailView(goal: goal)
        .modelContainer(for: [Goal.self, LinkedNote.self, Note.self])
} 