import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @StateObject private var navRouter = NavigationRouter()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(goals) { goal in
                        GoalDashboardCard(goal: goal)
                            .onTapGesture {
                                navRouter.navigateToGoalDetail(goal: goal)
                            }
                    }
                }
                .padding()
                
                if goals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("まだ目標が設定されていません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("目標を設定して継続的な習慣を身につけましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                }
            }
            .navigationTitle("ダッシュボード")
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
}

struct GoalDashboardCard: View {
    @Bindable var goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(goal.name)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text(goal.frequency.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("目標: \(goal.targetCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 進捗バー
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("進捗")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(goal.currentPeriodProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: goal.currentPeriodProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
            }
            
            // 連続日数（デイリー目標の場合のみ）
            if goal.frequency == .daily && goal.consecutiveDays > 0 {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("連続: \(goal.consecutiveDays) 日")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var progressColor: Color {
        if goal.currentPeriodProgress >= 1.0 {
            return .green
        } else if goal.currentPeriodProgress >= 0.7 {
            return .orange
        } else {
            return .blue
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Goal.self, LinkedNote.self])
} 