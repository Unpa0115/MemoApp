import SwiftUI

struct QualityCheckView: View {
    @Bindable var note: Note
    @Binding var isPresented: Bool
    
    @State private var issues: [QualityIssue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedIssue: QualityIssue?
    @State private var showAppliedChanges = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("メモの品質をチェックし、改善提案を表示します")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("品質チェックを実行") {
                    runQualityCheck()
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.content.isEmpty || isLoading)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("品質チェック実行ボタン")
                
                if note.content.isEmpty {
                    Text("メモに内容がありません。まずメモを入力してください。")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("品質をチェック中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                if !issues.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("検出された問題")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(issues.count)件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(issues) { issue in
                                    IssueCardView(
                                        issue: issue,
                                        note: note,
                                        onApply: { appliedIssue in
                                            applyFix(appliedIssue)
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        if showAppliedChanges {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("修正が適用されました")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("品質チェック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
                if !issues.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("再チェック") {
                            runQualityCheck()
                        }
                        .disabled(isLoading)
                    }
                }
            }
        }
        .onAppear {
            issues = []
            errorMessage = nil
            showAppliedChanges = false
        }
    }
    
    private func runQualityCheck() {
        guard !note.content.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        issues = []
        showAppliedChanges = false
        
        Task {
            do {
                let result = try await AIClient.shared.fetchQualityIssues(text: note.content)
                await MainActor.run {
                    self.issues = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.issues = []
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func applyFix(_ issue: QualityIssue) {
        // 単純な文字列置換での修正適用
        // より高度な実装では正規表現や文脈を考慮した置換を行う
        note.content = note.content.replacingOccurrences(
            of: issue.issueDescription,
            with: issue.suggestion
        )
        note.updatedAt = Date.now
        
        // 適用済みのissueを削除
        issues.removeAll { $0.id == issue.id }
        
        // フィードバック表示
        showAppliedChanges = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showAppliedChanges = false
        }
    }
}

struct IssueCardView: View {
    let issue: QualityIssue
    let note: Note
    let onApply: (QualityIssue) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 重要度アイコン
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.caption)
                
                // カテゴリバッジ
                Text(issue.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.2))
                    .foregroundColor(categoryColor)
                    .cornerRadius(4)
                
                Spacer()
                
                // 重要度テキスト
                Text(issue.severity.rawValue)
                    .font(.caption)
                    .foregroundColor(severityColor)
                
                // 展開ボタン
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            // 問題の説明
            Text(issue.issueDescription)
                .font(.body)
                .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("修正提案:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(issue.suggestion)
                        .font(.body)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                    
                    HStack(spacing: 12) {
                        Button("修正を適用") {
                            onApply(issue)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("クリップボードにコピー") {
                            UIPasteboard.general.string = issue.suggestion
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            isExpanded.toggle()
        }
    }
    
    private var severityIcon: String {
        switch issue.severity {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "xmark.octagon"
        }
    }
    
    private var severityColor: Color {
        switch issue.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    private var categoryColor: Color {
        switch issue.category {
        case .grammar: return .red
        case .style: return .blue
        case .clarity: return .orange
        case .factual: return .purple
        }
    }
} 