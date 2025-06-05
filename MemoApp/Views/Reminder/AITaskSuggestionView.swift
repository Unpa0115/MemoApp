import SwiftUI

struct AITaskSuggestionView: View {
    @Bindable var note: Note
    @State private var showingAITasks = false
    @State private var showingDatePicker = false
    @State private var selectedTask: AITask?
    @State private var customReminderDate = Date().addingTimeInterval(3600)
    @StateObject private var aiService = AITaskExtractionService.shared
    @StateObject private var reminderService = ReminderService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI タスク提案セクション
            Button(action: { 
                showingAITasks.toggle()
                if showingAITasks && note.aiSuggestedTasks.isEmpty {
                    Task {
                        await aiService.extractTasksForNote(note)
                    }
                }
            }) {
                HStack {
                    Label("AI でタスク提案を表示", systemImage: "brain.head.profile")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showingAITasks ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            
            if showingAITasks {
                VStack(alignment: .leading, spacing: 8) {
                    if note.aiSuggestedTasks.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("タスクを抽出中...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("提案されたタスク:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(note.aiSuggestedTasks) { task in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• \(task.description)")
                                        .font(.subheadline)
                                    
                                    if let date = task.suggestedDate {
                                        Text("推奨日時: \(date.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if let date = task.suggestedDate {
                                        reminderService.scheduleTaskReminder(task, for: note, at: date)
                                    } else {
                                        selectedTask = task
                                        showingDatePicker = true
                                    }
                                }) {
                                    Image(systemName: "bell")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingAITasks)
        .sheet(isPresented: $showingDatePicker) {
            if let task = selectedTask {
                NavigationView {
                    DatePickerSheet(
                        task: task,
                        note: note,
                        selectedDate: $customReminderDate,
                        isPresented: $showingDatePicker
                    )
                }
            }
        }
    }
}

struct DatePickerSheet: View {
    let task: AITask
    let note: Note
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @StateObject private var reminderService = ReminderService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("タスクのリマインダー日時を選択")
                .font(.headline)
                .padding(.top)
            
            Text(task.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            DatePicker(
                "日時を選択",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .padding()
            
            Spacer()
        }
        .navigationTitle("リマインダー設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("設定") {
                    reminderService.scheduleTaskReminder(task, for: note, at: selectedDate)
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    AITaskSuggestionView(note: Note(content: """
    # プロジェクト計画
    
    TODO: 企画書を作成する
    やること: チームメンバーと打ち合わせ
    タスク: デザインの確認
    """, title: "プロジェクト計画"))
        .padding()
} 