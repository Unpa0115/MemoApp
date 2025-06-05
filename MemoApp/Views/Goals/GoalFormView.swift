import SwiftUI
import SwiftData

struct GoalFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var frequency: Frequency = .daily
    @State private var targetCount = 1
    @State private var startDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var goal: Goal? // 編集の場合のみ設定
    
    init(goal: Goal? = nil) {
        self.goal = goal
        if let goal = goal {
            _name = State(initialValue: goal.name)
            _frequency = State(initialValue: goal.frequency)
            _targetCount = State(initialValue: goal.targetCount)
            _startDate = State(initialValue: goal.startDate)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("目標設定")) {
                    TextField("目標名を入力", text: $name)
                        .accessibilityLabel("目標名入力フィールド")
                    
                    Picker("周期", selection: $frequency) {
                        ForEach(Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Stepper("目標回数: \(targetCount)", value: $targetCount, in: 1...10)
                        .accessibilityLabel("目標回数設定")
                        .accessibilityValue("\(targetCount)回")
                    
                    DatePicker(
                        "開始日",
                        selection: $startDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
                
                Section(footer: Text("目標を設定して継続的な習慣を身につけましょう")) {
                    // 空のセクション
                }
            }
            .navigationTitle(goal == nil ? "新しい目標" : "目標編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveGoal()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("エラー", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveGoal() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "目標名を入力してください"
            showingAlert = true
            return
        }
        
        if let existingGoal = goal {
            // 編集モード
            existingGoal.name = trimmedName
            existingGoal.frequency = frequency
            existingGoal.targetCount = targetCount
            existingGoal.startDate = startDate
        } else {
            // 新規作成モード
            let newGoal = Goal(
                name: trimmedName,
                frequency: frequency,
                targetCount: targetCount,
                startDate: startDate
            )
            context.insert(newGoal)
        }
        
        do {
            try context.save()
            dismiss()
        } catch {
            alertMessage = "目標の保存に失敗しました: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    GoalFormView()
        .modelContainer(for: [Goal.self, LinkedNote.self])
} 