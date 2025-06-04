import SwiftUI
import WebKit
import Foundation

struct MarkdownPreviewView: UIViewRepresentable {
    let markdown: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = convertMarkdownToHTML(markdown)
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    margin: 16px;
                    color: \(colorScheme == .dark ? "#ffffff" : "#000000");
                    background-color: \(colorScheme == .dark ? "#1c1c1e" : "#ffffff");
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                }
                p {
                    margin-bottom: 16px;
                }
                code {
                    background-color: \(colorScheme == .dark ? "#2c2c2e" : "#f6f8fa");
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, Consolas, monospace;
                }
                pre {
                    background-color: \(colorScheme == .dark ? "#2c2c2e" : "#f6f8fa");
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                }
                blockquote {
                    border-left: 4px solid \(colorScheme == .dark ? "#444446" : "#d1d5da");
                    margin: 0;
                    padding-left: 16px;
                    color: \(colorScheme == .dark ? "#8e8e93" : "#6a737d");
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    class Coordinator: NSObject, WKNavigationDelegate {
        // WebViewの設定やナビゲーション処理
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        do {
            // NSStringに変換してUTF-16ベースで処理
            var nsString = html as NSString
            
            // 見出し（NSRegularExpressionを使用）
            let h1Regex = try NSRegularExpression(pattern: "^# (.+)$", options: [.anchorsMatchLines])
            html = h1Regex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "<h1>$1</h1>")
            nsString = html as NSString
            
            let h2Regex = try NSRegularExpression(pattern: "^## (.+)$", options: [.anchorsMatchLines])
            html = h2Regex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "<h2>$1</h2>")
            nsString = html as NSString
            
            let h3Regex = try NSRegularExpression(pattern: "^### (.+)$", options: [.anchorsMatchLines])
            html = h3Regex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "<h3>$1</h3>")
            nsString = html as NSString
            
            // 太字
            let boldRegex = try NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
            html = boldRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "<strong>$1</strong>")
            nsString = html as NSString
            
            // イタリック（太字以外の単一アスタリスク）
            let italicRegex = try NSRegularExpression(pattern: "(?<!\\*)\\*([^\\*]+?)\\*(?!\\*)", options: [])
            html = italicRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "<em>$1</em>")
            nsString = html as NSString
            
            // インラインコード
            let codeRegex = try NSRegularExpression(pattern: "`([^`]+?)`", options: [])
            html = codeRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "<code>$1</code>")
            
        } catch {
            print("正規表現エラー: \(error)")
        }
        
        // 段落の処理（見出しでない行を<p>タグで囲む）
        let lines = html.components(separatedBy: .newlines)
        let processedLines = lines.map { line -> String in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                return "<br>"
            } else if trimmedLine.hasPrefix("<h") || trimmedLine.contains("<h") {
                return trimmedLine
            } else {
                return "<p>\(trimmedLine)</p>"
            }
        }
        
        html = processedLines.joined(separator: "\n")
        
        return html
    }
} 