import SwiftUI

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title ?? "（無題）")
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                if note.isDraft {
                    Image(systemName: "pencil")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            // 本文プレビュー
            if !note.content.isEmpty {
                Text(contentPreview)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                // カテゴリ表示
                if !note.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(note.categories.prefix(2), id: \.id) { category in
                                Label(category.name, systemImage: "folder")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if note.categories.count > 2 {
                                Text("+\(note.categories.count - 2)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 更新日時
                Text(formattedUpdatedAt)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // タグ表示
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(3), id: \.id) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        if note.tags.count > 3 {
                            Text("+\(note.tags.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var contentPreview: String {
        let content = note.content
        let cleanContent = content.replacingOccurrences(of: "\n", with: " ")
        if cleanContent.count > 100 {
            let index = cleanContent.index(cleanContent.startIndex, offsetBy: 100)
            return String(cleanContent[..<index]) + "…"
        }
        return cleanContent
    }
    
    private var formattedUpdatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: note.updatedAt)
    }
} 