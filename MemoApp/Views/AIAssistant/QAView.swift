import SwiftUI

struct QAView: View {
    @Bindable var note: Note
    
    @State private var question: String = ""
    @State private var chatHistory: [QAItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("メモの内容について質問できます")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                TextField("質問を入力…", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("質問入力フィールド")
                    .onSubmit {
                        if !question.isEmpty && !isLoading {
                            sendQuestion()
                        }
                    }
                
                Button(action: sendQuestion) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(question.isEmpty || isLoading || note.content.isEmpty)
                .accessibilityLabel("質問送信ボタン")
            }
            
            if note.content.isEmpty {
                Text("メモに内容がありません。まずメモを入力してください。")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
            
            if !chatHistory.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(chatHistory) { qa in
                            VStack(alignment: .leading, spacing: 8) {
                                // 質問
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("質問")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(qa.question)
                                            .font(.body)
                                            .padding(8)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // 回答
                                if !qa.answer.isEmpty {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "brain")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("回答")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(qa.answer)
                                                .font(.body)
                                                .padding(8)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(8)
                                                .textSelection(.enabled)
                                                .contextMenu {
                                                    Button("メモに追加") {
                                                        insertAnswer(qa.answer)
                                                    }
                                                    Button("クリップボードにコピー") {
                                                        UIPasteboard.general.string = qa.answer
                                                    }
                                                }
                                        }
                                        
                                        Spacer()
                                    }
                                } else {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.7)
                                        Text("回答を生成中...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
            }
        }
        .onAppear {
            chatHistory = []
            errorMessage = nil
        }
    }
    
    private func sendQuestion() {
        guard !question.isEmpty && !note.content.isEmpty else { return }
        
        let currentQuestion = question
        question = ""
        isLoading = true
        errorMessage = nil
        
        // 質問をチャット履歴に追加（回答は空で）
        let qaItem = QAItem(question: currentQuestion, answer: "")
        chatHistory.append(qaItem)
        
        Task {
            do {
                let answer = try await AIClient.shared.fetchQAResponse(
                    content: note.content,
                    question: currentQuestion
                )
                
                await MainActor.run {
                    // 最新のQAItemに回答を設定
                    if let lastIndex = chatHistory.indices.last {
                        chatHistory[lastIndex] = QAItem(
                            id: chatHistory[lastIndex].id,
                            question: currentQuestion,
                            answer: answer
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // エラーの場合、回答にエラーメッセージを設定
                    if let lastIndex = chatHistory.indices.last {
                        chatHistory[lastIndex] = QAItem(
                            id: chatHistory[lastIndex].id,
                            question: currentQuestion,
                            answer: "回答の取得に失敗しました: \(error.localizedDescription)"
                        )
                    }
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func insertAnswer(_ answer: String) {
        let formattedAnswer = "\n\n**AI回答:** \(answer)\n"
        note.content += formattedAnswer
        note.updatedAt = Date.now
    }
} 