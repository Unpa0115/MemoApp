import SwiftUI

struct RichMarkdownEditor: View {
    @Binding var text: String
    let onTextChange: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // ツールバー
            MarkdownToolbar(onSymbolTap: { symbol in
                insertSymbol(symbol)
            })
            
            Divider()
            
            // エディタ
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .onChange(of: text) { oldValue, newValue in
                    onTextChange(newValue)
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
        }
    }
    
    private func insertSymbol(_ symbol: String) {
        text += symbol
        onTextChange(text)
    }
}

struct MarkdownToolbar: View {
    let onSymbolTap: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ToolbarButton(title: "H1", symbol: "# ") { onSymbolTap("# ") }
                ToolbarButton(title: "H2", symbol: "## ") { onSymbolTap("## ") }
                ToolbarButton(title: "H3", symbol: "### ") { onSymbolTap("### ") }
                
                Divider()
                    .frame(height: 20)
                
                ToolbarButton(title: "太字", symbol: "**") { onSymbolTap("****") }
                ToolbarButton(title: "斜体", symbol: "*") { onSymbolTap("**") }
                ToolbarButton(title: "コード", symbol: "`") { onSymbolTap("``") }
                
                Divider()
                    .frame(height: 20)
                
                ToolbarButton(title: "リンク", symbol: "[]()") { onSymbolTap("[](") }
                ToolbarButton(title: "画像", symbol: "![]()") { onSymbolTap("![](") }
                ToolbarButton(title: "リスト", symbol: "- ") { onSymbolTap("- ") }
                ToolbarButton(title: "番号", symbol: "1. ") { onSymbolTap("1. ") }
                
                Divider()
                    .frame(height: 20)
                
                ToolbarButton(title: "引用", symbol: "> ") { onSymbolTap("> ") }
                ToolbarButton(title: "コードブロック", symbol: "```") { onSymbolTap("```\n\n```") }
                ToolbarButton(title: "水平線", symbol: "---") { onSymbolTap("\n---\n") }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct ToolbarButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .foregroundColor(.primary)
    }
} 