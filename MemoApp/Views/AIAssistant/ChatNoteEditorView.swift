import SwiftUI
import SwiftData

struct ChatNoteEditorView: View {
    @Bindable var note: Note
    @StateObject private var conversationVM = ConversationViewModel()
    @State private var splitRatio: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // メモキャンバス（左）
                VStack(spacing: 0) {
                    Text("メモ")
                        .font(.headline)
                        .padding(.vertical, 8)
                    
                    Divider()
                    
                    TextEditor(text: $note.content)
                        .font(.body)
                        .padding()
                        .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { _ in
                            note.updatedAt = Date.now
                        }
                }
                .frame(width: geometry.size.width * splitRatio)
                .background(Color(.systemBackground))
                
                // 分割線
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newRatio = max(0.3, min(0.7, splitRatio + value.translation.width / geometry.size.width))
                                splitRatio = newRatio
                            }
                    )
                
                // チャットUI（右）
                VStack(spacing: 0) {
                    Text("AIチャット")
                        .font(.headline)
                        .padding(.vertical, 8)
                    
                    Divider()
                    
                    // メッセージ履歴
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(conversationVM.messages) { message in
                                    MessageBubbleView(message: message, note: note)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: conversationVM.messages.count) {
                            if let lastMessage = conversationVM.messages.last {
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 入力エリア
                    HStack(spacing: 8) {
                        TextField("メッセージを入力…", text: $conversationVM.currentInput, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)
                            .onSubmit {
                                if !conversationVM.currentInput.isEmpty && !conversationVM.isLoading {
                                    sendMessage()
                                }
                            }
                        
                        Button(action: sendMessage) {
                            if conversationVM.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .disabled(conversationVM.currentInput.isEmpty || conversationVM.isLoading)
                        .accessibilityLabel("メッセージ送信")
                    }
                    .padding()
                }
                .frame(width: geometry.size.width * (1 - splitRatio))
                .background(Color(.secondarySystemBackground))
            }
        }
        .navigationTitle("会話型メモ作成")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            conversationVM.startNewConversation()
        }
    }
    
    private func sendMessage() {
        let userInput = conversationVM.currentInput
        conversationVM.addUserMessage(text: userInput)
        conversationVM.currentInput = ""
        
        Task {
            do {
                let response = try await AIClient.shared.fetchQAResponse(
                    content: note.content.isEmpty ? "空のメモ" : note.content,
                    question: userInput
                )
                conversationVM.addAssistantMessage(text: response)
            } catch {
                conversationVM.addAssistantMessage(text: "申し訳ございません。回答の取得に失敗しました: \(error.localizedDescription)")
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    let note: Note
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // アイコン
            Image(systemName: message.role == .assistant ? "brain" : "person.fill")
                .foregroundColor(message.role == .assistant ? .green : .blue)
                .font(.caption)
                .frame(width: 20)
            
            // メッセージ内容
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .assistant ? "AI" : "あなた")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.body)
                    .padding(8)
                    .background(message.role == .assistant ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .contextMenu {
                        if message.role == .assistant {
                            Button("メモに追加") {
                                insertToNote(message.content)
                            }
                        }
                        Button("クリップボードにコピー") {
                            UIPasteboard.general.string = message.content
                        }
                    }
            }
            
            Spacer()
        }
    }
    
    private func insertToNote(_ content: String) {
        let formattedContent = "\n\n**AI提案:** \(content)\n"
        note.content += formattedContent
        note.updatedAt = Date.now
    }
}

/// 会話状態を管理する ViewModel
@MainActor
class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    
    func startNewConversation() {
        messages.removeAll()
        // ウェルカムメッセージを追加
        addAssistantMessage(text: "こんにちは！メモ作成のお手伝いをいたします。何についてお話ししましょうか？")
    }
    
    func addUserMessage(text: String) {
        let message = Message(role: .user, content: text)
        messages.append(message)
        isLoading = true
    }
    
    func addAssistantMessage(text: String) {
        let message = Message(role: .assistant, content: text)
        messages.append(message)
        isLoading = false
    }
} 