import SwiftUI

struct AISheetView: View {
    @Bindable var note: Note
    @Binding var isPresented: Bool
    var initialTab: AITab? = nil
    
    @State private var selectedTab: AITab = .ideas
    @State private var showAPIKeySettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブ選択（常に表示）
                Picker("機能選択", selection: $selectedTab) {
                    ForEach(AITab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // APIキーチェックとコンテンツ
                if !KeychainService.shared.hasOpenAIKey() {
                    // APIキーが必要な機能のエラー表示
                    VStack(spacing: 16) {
                        Image(systemName: "key.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("API キーが設定されていません")
                            .font(.headline)
                        
                        Text("この機能を使用するには、OpenAI API キーの設定が必要です。")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("API キーを設定") {
                            showAPIKeySettings = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // サブ機能コンテンツ
                    ScrollView {
                        Group {
                            switch selectedTab {
                            case .ideas:
                                IdeaBrainstormingView(note: note)
                            case .summary:
                                SummaryView(note: note)
                            case .qa:
                                QAView(note: note)
                            case .template:
                                TemplateView(note: note)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("AIアシスタント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !KeychainService.shared.hasOpenAIKey() {
                            Button("API キーを設定") {
                                showAPIKeySettings = true
                            }
                            Divider()
                        }
                        NavigationLink("会話型メモ") {
                            ChatNoteEditorView(note: note)
                        }
                        Button("翻訳・言い換え") {
                            // 翻訳シートを開く処理
                        }
                        Button("品質チェック") {
                            // 品質チェックシートを開く処理
                        }
                    } label: {
                        Image(systemName: !KeychainService.shared.hasOpenAIKey() ? "key.slash" : "ellipsis.circle")
                            .foregroundColor(!KeychainService.shared.hasOpenAIKey() ? .orange : .primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
        .onAppear {
            if let initialTab = initialTab {
                selectedTab = initialTab
            }
        }
    }
}

/// AIサブ機能タブ
enum AITab: CaseIterable {
    case ideas, summary, qa, template
    
    var title: String {
        switch self {
        case .ideas: return "アイデア"
        case .summary: return "要約"
        case .qa: return "Q&A"
        case .template: return "テンプレート"
        }
    }
} 