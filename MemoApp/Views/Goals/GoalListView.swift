import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @State private var showingGoalForm = false
    @StateObject private var navRouter = NavigationRouter()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(goals) { goal in
                    GoalRowView(goal: goal)
                        .onTapGesture {
                            navRouter.navigateToGoalDetail(goal: goal)
                        }
                }
                .onDelete(perform: deleteGoals)
            }
            .navigationTitle("目標管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingGoalForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingGoalForm) {
                GoalFormView()
            }
            .sheet(isPresented: $navRouter.showGoalDetail) {
                if let goal = navRouter.selectedGoal {
                    NavigationView {
                        GoalDetailView(goal: goal)
                    }
                }
            }
        }
        .environmentObject(navRouter)
    }
    
    private func deleteGoals(offsets: IndexSet) {
        for index in offsets {
            context.delete(goals[index])
        }
        try? context.save()
    }
}

struct GoalRowView: View {
    @Bindable var goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                Text(goal.frequency.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack {
                Text("進捗:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ProgressView(value: goal.currentPeriodProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                Text("\(Int(goal.currentPeriodProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if goal.frequency == .daily && goal.consecutiveDays > 0 {
                Text("連続: \(goal.consecutiveDays) 日")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text("目標: \(goal.targetCount) 回 / \(goal.frequency.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GoalListView()
        .modelContainer(for: [Goal.self, LinkedNote.self])
} 