import SwiftUI
import UIKit

struct RichMarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    let onTextChange: (String) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.backgroundColor = UIColor.systemBackground
        textView.textColor = UIColor.label
        
        // 入力中のリアルタイム更新を有効にする
        textView.allowsEditingTextAttributes = true
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            let attributedText = createAttributedString(from: text)
            textView.attributedText = attributedText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichMarkdownEditor
        
        init(_ parent: RichMarkdownEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)
            
            // リアルタイムでAttributedStringを適用
            let attributedText = parent.createAttributedString(from: textView.text)
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
        }
    }
    
    private func createAttributedString(from markdown: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: markdown)
        let range = NSRange(location: 0, length: attributedString.length)
        
        // ベースフォントとカラーを設定
        attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        
        do {
            // 見出し1のスタイリング
            let h1Regex = try NSRegularExpression(pattern: "^# (.+)$", options: [.anchorsMatchLines])
            h1Regex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 28), range: matchRange)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: matchRange)
                }
            }
            
            // 見出し2のスタイリング
            let h2Regex = try NSRegularExpression(pattern: "^## (.+)$", options: [.anchorsMatchLines])
            h2Regex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 22), range: matchRange)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: matchRange)
                }
            }
            
            // 見出し3のスタイリング
            let h3Regex = try NSRegularExpression(pattern: "^### (.+)$", options: [.anchorsMatchLines])
            h3Regex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 18), range: matchRange)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: matchRange)
                }
            }
            
            // 太字のスタイリング
            let boldRegex = try NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
            boldRegex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: matchRange)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.systemRed, range: matchRange)
                }
            }
            
            // イタリックのスタイリング
            let italicRegex = try NSRegularExpression(pattern: "(?<!\\*)\\*([^\\*]+?)\\*(?!\\*)", options: [])
            italicRegex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 17), range: matchRange)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: matchRange)
                }
            }
            
            // インラインコードのスタイリング
            let codeRegex = try NSRegularExpression(pattern: "`([^`]+?)`", options: [])
            codeRegex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular), range: matchRange)
                    attributedString.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: matchRange)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: matchRange)
                }
            }
            
        } catch {
            print("正規表現エラー: \(error)")
        }
        
        return attributedString
    }
} 