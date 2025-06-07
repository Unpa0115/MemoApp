import SwiftUI

struct IdeaBrainstormingView: View {
    @Bindable var note: Note
    
    @State private var theme: String = ""
    @State private var keywords: String = ""
    @State private var suggestions: [IdeaSuggestion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("テーマとキーワードを入力してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                TextField("テーマ", text: $theme)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("テーマ入力フィールド")
                
                TextField("キーワード（カンマ区切り）", text: $keywords)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("キーワード入力フィールド")
            }
            
            Button(action: fetchSuggestions) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    }
                    Text("アイデアを生成")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled((theme.isEmpty && keywords.isEmpty) || isLoading)
            .accessibilityLabel("アイデア生成ボタン")
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
            
            if !suggestions.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("生成されたアイデア")
                        .font(.headline)
                    
                    ForEach(suggestions) { suggestion in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                                .font(.title2)
                            
                            Text(suggestion.text)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            Button(action: {
                                insertIdea(suggestion.text)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel("メモに追加")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            insertIdea(suggestion.text)
                        }
                    }
                }
            }
        }
        .onAppear {
            suggestions = []
            errorMessage = nil
        }
    }
    
    private func fetchSuggestions() {
        guard !theme.isEmpty || !keywords.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await AIClient.shared.fetchIdeaSuggestions(
                    theme: theme.isEmpty ? "一般的なトピック" : theme,
                    keywords: keywords
                )
                await MainActor.run {
                    self.suggestions = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.suggestions = []
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// アイデアをメモに貼り付け
    private func insertIdea(_ idea: String) {
        let formattedIdea = "\n- \(idea)\n"
        note.content += formattedIdea
        note.updatedAt = Date.now
        
        // 視覚的フィードバック
        withAnimation(.easeInOut(duration: 0.2)) {
            // アニメーション効果を追加する場合はここに実装
        }
    }
} 