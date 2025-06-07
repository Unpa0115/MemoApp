import SwiftUI

struct ReminderSectionView: View {
    @Bindable var note: Note
    @State private var reminderDate = Date().addingTimeInterval(3600) // 1時間後がデフォルト
    @StateObject private var reminderService = ReminderService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // リマインダー設定トグル
            Toggle("リマインダー設定", isOn: Binding(
                get: { note.hasReminder ?? false },
                set: { newValue in
                    note.hasReminder = newValue
                    if newValue {
                        note.reminderDate = reminderDate
                    } else {
                        note.reminderDate = nil
                        reminderService.removePendingReminder(for: note)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle())
            
            // 日時選択フィールド
            if note.hasReminder ?? false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("リマインダー日時")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker(
                        "日時を選択",
                        selection: Binding(
                            get: { note.reminderDate ?? reminderDate },
                            set: { newDate in
                                reminderDate = newDate
                                note.reminderDate = newDate
                            }
                        ),
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: note.hasReminder ?? false)
        .onAppear {
            if let existingDate = note.reminderDate {
                reminderDate = existingDate
            }
        }
    }
}

#Preview {
    ReminderSectionView(note: Note(content: "サンプルメモ", title: "テストタイトル"))
        .padding()
} 