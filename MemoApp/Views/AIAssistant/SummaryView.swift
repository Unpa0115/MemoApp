import SwiftUI

struct SummaryView: View {
    @Bindable var note: Note
    
    @State private var summaryType: SummaryType = .threeLines
    @State private var resultText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("メモの要約を生成します")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("要約タイプ", selection: $summaryType) {
                ForEach(SummaryType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("要約タイプ選択")
            
            Button(action: fetchSummary) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    }
                    Text("要約を生成")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(note.content.isEmpty || isLoading)
            .accessibilityLabel("要約生成ボタン")
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
            
            if !resultText.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("生成された要約")
                        .font(.headline)
                    
                    ScrollView {
                        Text(resultText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    
                    HStack(spacing: 12) {
                        Button("メモに挿入") {
                            insertSummary()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("置換") {
                            replaceSummary()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = resultText
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("クリップボードにコピー")
                    }
                }
            }
        }
        .onAppear {
            resultText = ""
            errorMessage = nil
        }
    }
    
    private func fetchSummary() {
        guard !note.content.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        resultText = ""
        
        Task {
            do {
                let summary = try await AIClient.shared.fetchSummary(
                    content: note.content,
                    type: summaryType
                )
                await MainActor.run {
                    self.resultText = summary.text
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.resultText = ""
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func insertSummary() {
        let formattedSummary = "\n\n## 要約\n\n\(resultText)\n"
        note.content += formattedSummary
        note.updatedAt = Date.now
    }
    
    private func replaceSummary() {
        note.content = resultText
        note.updatedAt = Date.now
    }
} 