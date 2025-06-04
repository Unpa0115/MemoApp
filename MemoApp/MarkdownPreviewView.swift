import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(processedElements, id: \.id) { element in
                    element.view
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }
    
    private var processedElements: [MarkdownElement] {
        parseMarkdown(markdown)
    }
}

struct MarkdownElement: Identifiable {
    let id = UUID()
    let view: AnyView
}

private func parseMarkdown(_ text: String) -> [MarkdownElement] {
    let lines = text.components(separatedBy: .newlines)
    var elements: [MarkdownElement] = []
    var currentCodeBlock: [String] = []
    var inCodeBlock = false
    
    for line in lines {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            if inCodeBlock {
                // コードブロック終了
                let codeContent = currentCodeBlock.joined(separator: "\n")
                elements.append(MarkdownElement(view: AnyView(CodeBlockView(code: codeContent))))
                currentCodeBlock.removeAll()
                inCodeBlock = false
            } else {
                // コードブロック開始
                inCodeBlock = true
            }
            continue
        }
        
        if inCodeBlock {
            currentCodeBlock.append(line)
            continue
        }
        
        // 空行の処理
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            elements.append(MarkdownElement(view: AnyView(Spacer().frame(height: 8))))
            continue
        }
        
        // ヘッダーの処理
        if line.hasPrefix("### ") {
            let text = String(line.dropFirst(4))
            elements.append(MarkdownElement(view: AnyView(
                Text(text)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            )))
        } else if line.hasPrefix("## ") {
            let text = String(line.dropFirst(3))
            elements.append(MarkdownElement(view: AnyView(
                Text(text)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            )))
        } else if line.hasPrefix("# ") {
            let text = String(line.dropFirst(2))
            elements.append(MarkdownElement(view: AnyView(
                Text(text)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            )))
        }
        // 引用の処理
        else if line.hasPrefix("> ") {
            let text = String(line.dropFirst(2))
            elements.append(MarkdownElement(view: AnyView(
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .frame(width: 3)
                        .foregroundColor(.blue)
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.leading)
            )))
        }
        // リストの処理
        else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            let text = String(line.dropFirst(2))
            elements.append(MarkdownElement(view: AnyView(
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(formatInlineMarkdown(text))
                        .font(.body)
                }
                .padding(.leading)
            )))
        }
        // 番号付きリストの処理
        else if line.matches(regex: "^\\d+\\. ") {
            let components = line.split(separator: " ", maxSplits: 1)
            if components.count == 2 {
                let number = components[0]
                let text = String(components[1])
                elements.append(MarkdownElement(view: AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(number))
                            .font(.body)
                            .foregroundColor(.primary)
                        Text(formatInlineMarkdown(text))
                            .font(.body)
                    }
                    .padding(.leading)
                )))
            }
        }
        // 水平線の処理
        else if line.trimmingCharacters(in: .whitespaces) == "---" {
            elements.append(MarkdownElement(view: AnyView(
                Divider()
                    .padding(.vertical, 8)
            )))
        }
        // 通常のテキスト
        else {
            elements.append(MarkdownElement(view: AnyView(
                Text(formatInlineMarkdown(line))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            )))
        }
    }
    
    return elements
}

private func formatInlineMarkdown(_ text: String) -> AttributedString {
    var attributed = AttributedString(text)
    
    // 太字の処理 (**text**)
    let boldPattern = "\\*\\*(.*?)\\*\\*"
    if let regex = try? NSRegularExpression(pattern: boldPattern) {
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            if let range = Range(match.range, in: text) {
                let boldText = String(text[range]).replacingOccurrences(of: "**", with: "")
                if let attrRange = attributed.range(of: String(text[range])) {
                    attributed[attrRange].font = .body.bold()
                    attributed.replaceSubrange(attrRange, with: AttributedString(boldText))
                }
            }
        }
    }
    
    // 斜体の処理 (*text*)
    let italicPattern = "\\*(.*?)\\*"
    if let regex = try? NSRegularExpression(pattern: italicPattern) {
        let matches = regex.matches(in: attributed.description, range: NSRange(attributed.description.startIndex..., in: attributed.description))
        for match in matches.reversed() {
            if let range = Range(match.range, in: attributed.description) {
                let italicText = String(attributed.description[range]).replacingOccurrences(of: "*", with: "")
                if let attrRange = attributed.range(of: String(attributed.description[range])) {
                    attributed[attrRange].font = .body.italic()
                    attributed.replaceSubrange(attrRange, with: AttributedString(italicText))
                }
            }
        }
    }
    
    // インラインコードの処理 (`code`)
    let codePattern = "`(.*?)`"
    if let regex = try? NSRegularExpression(pattern: codePattern) {
        let matches = regex.matches(in: attributed.description, range: NSRange(attributed.description.startIndex..., in: attributed.description))
        for match in matches.reversed() {
            if let range = Range(match.range, in: attributed.description) {
                let codeText = String(attributed.description[range]).replacingOccurrences(of: "`", with: "")
                if let attrRange = attributed.range(of: String(attributed.description[range])) {
                    attributed[attrRange].font = .system(.body, design: .monospaced)
                    attributed[attrRange].backgroundColor = .gray.opacity(0.2)
                    attributed.replaceSubrange(attrRange, with: AttributedString(codeText))
                }
            }
        }
    }
    
    return attributed
}

struct CodeBlockView: View {
    let code: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
} 