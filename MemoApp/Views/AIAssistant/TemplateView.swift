import SwiftUI

struct TemplateView: View {
    @Bindable var note: Note
    
    @State private var selectedCategory: TemplateCategory = .taskManagement
    @State private var generatedTemplate: TemplateResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("テンプレート用途を選択してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("用途選択", selection: $selectedCategory) {
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .accessibilityLabel("テンプレート用途選択")
            
            Button(action: fetchTemplate) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    }
                    Text("テンプレートを生成")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .accessibilityLabel("テンプレート生成ボタン")
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
            
            if let template = generatedTemplate {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("生成されたテンプレート: \(template.title)")
                        .font(.headline)
                    
                    ScrollView {
                        Text(template.markdownContent)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 250)
                    
                    HStack(spacing: 12) {
                        Button("メモに挿入") {
                            insertTemplate(template.markdownContent)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("置換") {
                            replaceTemplate(template.markdownContent)
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = template.markdownContent
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("クリップボードにコピー")
                        
                        Button(action: {
                            shareTemplate(template.markdownContent)
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("共有")
                    }
                }
            }
        }
        .onAppear {
            generatedTemplate = nil
            errorMessage = nil
        }
    }
    
    private func fetchTemplate() {
        isLoading = true
        errorMessage = nil
        generatedTemplate = nil
        
        Task {
            do {
                let result = try await AIClient.shared.fetchTemplate(category: selectedCategory)
                await MainActor.run {
                    self.generatedTemplate = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.generatedTemplate = nil
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func insertTemplate(_ markdown: String) {
        let formattedTemplate = "\n\n\(markdown)\n"
        note.content += formattedTemplate
        note.updatedAt = Date.now
    }
    
    private func replaceTemplate(_ markdown: String) {
        note.content = markdown
        note.updatedAt = Date.now
    }
    
    private func shareTemplate(_ markdown: String) {
        let activityVC = UIActivityViewController(
            activityItems: [markdown],
            applicationActivities: nil
        )
        
        // iPadでの表示位置を設定
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