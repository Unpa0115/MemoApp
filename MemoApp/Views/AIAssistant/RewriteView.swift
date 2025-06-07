import SwiftUI

struct RewriteView: View {
    @Bindable var note: Note
    @Binding var isPresented: Bool
    
    @State private var rewriteType: RewriteType = .translateEn
    @State private var rewrittenText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showComparison = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("翻訳・言い換えモードを選択してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("モード選択", selection: $rewriteType) {
                    ForEach(RewriteType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("翻訳・言い換えモード選択")
                
                Button(action: fetchRewrite) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                        Text("変換を実行")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.content.isEmpty || isLoading)
                .accessibilityLabel("変換実行ボタン")
                
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
                
                if !rewrittenText.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("変換結果")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(showComparison ? "結果のみ表示" : "比較表示") {
                                showComparison.toggle()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        if showComparison {
                            // サイドバイサイド比較表示
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("元の文章")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView {
                                        Text(note.content)
                                            .font(.body)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("変換後")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView {
                                        Text(rewrittenText)
                                            .font(.body)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        } else {
                            // 結果のみ表示
                            ScrollView {
                                Text(rewrittenText)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 200)
                        }
                        
                        HStack(spacing: 12) {
                            Button("メモを置換") {
                                replaceNote()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("末尾に追加") {
                                appendToNote()
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = rewrittenText
                            }) {
                                Image(systemName: "doc.on.clipboard")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("クリップボードにコピー")
                            
                            Button(action: {
                                shareText(rewrittenText)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("共有")
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("翻訳・言い換え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            rewrittenText = ""
            errorMessage = nil
            showComparison = false
        }
    }
    
    private func fetchRewrite() {
        guard !note.content.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        rewrittenText = ""
        
        Task {
            do {
                let result = try await AIClient.shared.fetchRewrite(
                    original: note.content,
                    type: rewriteType
                )
                await MainActor.run {
                    self.rewrittenText = result.rewritten
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.rewrittenText = ""
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func replaceNote() {
        note.content = rewrittenText
        note.updatedAt = Date.now
        isPresented = false
    }
    
    private func appendToNote() {
        let formattedText = "\n\n---\n\n**[\(rewriteType.displayName)]**\n\n\(rewrittenText)\n"
        note.content += formattedText
        note.updatedAt = Date.now
    }
    
    private func shareText(_ text: String) {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
} 