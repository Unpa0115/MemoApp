import SwiftUI
import SwiftData

// MARK: - Search View

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var selectedTags: Set<Tag> = []
    
    var body: some View {
        NavigationStack {
            VStack {
                // 検索バー
                SearchBarView(searchText: $searchText)
                
                // フィルターセクション
                FilterSectionView(
                    selectedCategory: $selectedCategory,
                    selectedTags: $selectedTags
                )
                
                // 検索結果
                SearchResultsListView(
                    searchText: searchText,
                    selectedCategory: selectedCategory,
                    selectedTags: selectedTags
                )
            }
            .navigationTitle("検索")
        }
    }
}

// MARK: - Search Bar View

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("メモを検索…", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Filter Section View

struct FilterSectionView: View {
    @Binding var selectedCategory: Category?
    @Binding var selectedTags: Set<Tag>
    
    @Query(sort: \Category.name, order: .forward) private var allCategories: [Category]
    @Query(sort: \Tag.name, order: .forward) private var allTags: [Tag]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // カテゴリフィルター
            if !allCategories.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("カテゴリ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryFilterChip(
                                category: nil,
                                isSelected: selectedCategory == nil,
                                onTap: { selectedCategory = nil }
                            )
                            
                            ForEach(allCategories) { category in
                                CategoryFilterChip(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id,
                                    onTap: { 
                                        selectedCategory = selectedCategory?.id == category.id ? nil : category
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // タグフィルター
            if !allTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("タグ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allTags) { tag in
                                TagFilterChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    onTap: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Chip Views

struct CategoryFilterChip: View {
    let category: Category?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(category?.name ?? "すべて")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct TagFilterChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(tag.name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Search Results List View

struct SearchResultsListView: View {
    let searchText: String
    let selectedCategory: Category?
    let selectedTags: Set<Tag>
    
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    
    private var filteredNotes: [Note] {
        var notes = allNotes
        
        // キーワード検索
        if !searchText.isEmpty {
            notes = notes.filter { note in
                (note.title?.localizedStandardContains(searchText) == true) ||
                note.content.localizedStandardContains(searchText) ||
                note.tags.contains { $0.name.localizedStandardContains(searchText) } ||
                note.categories.contains { $0.name.localizedStandardContains(searchText) }
            }
        }
        
        // カテゴリフィルタ
        if let category = selectedCategory {
            notes = notes.filter { note in
                note.categories.contains { $0.id == category.id }
            }
        }
        
        // タグフィルタ
        if !selectedTags.isEmpty {
            let tagIds = Set(selectedTags.map { $0.id })
            notes = notes.filter { note in
                note.tags.contains { tagIds.contains($0.id) }
            }
        }
        
        return notes
    }
    
    var body: some View {
        List {
            if searchText.isEmpty && selectedCategory == nil && selectedTags.isEmpty {
                Text("検索キーワードまたはフィルターを指定してください")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if filteredNotes.isEmpty {
                Text("検索結果が見つかりませんでした")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredNotes) { note in
                    NavigationLink(value: note) {
                        SearchResultRowView(note: note, searchText: searchText)
                    }
                }
            }
        }
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
    }
}

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    let note: Note
    let searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タイトル（ハイライト付き）
            if let title = note.title {
                highlightedText(title, searchTerm: searchText)
                    .font(.headline)
                    .lineLimit(2)
            }
            
            // 本文プレビュー（ハイライト付き）
            highlightedText(contentPreview, searchTerm: searchText)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                // カテゴリ
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
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // タグ
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(note.tags, id: \.id) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var contentPreview: String {
        let content = note.content
        if content.count > 150 {
            let index = content.index(content.startIndex, offsetBy: 150)
            return String(content[..<index]) + "…"
        }
        return content
    }
    
    @ViewBuilder
    private func highlightedText(_ text: String, searchTerm: String) -> some View {
        if searchTerm.isEmpty {
            Text(text)
        } else {
            let attributedString = createHighlightedAttributedString(text: text, searchTerm: searchTerm)
            Text(attributedString)
        }
    }
    
    private func createHighlightedAttributedString(text: String, searchTerm: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        guard !searchTerm.isEmpty else { return attributedString }
        
        let searchLower = searchTerm.lowercased()
        let textLower = text.lowercased()
        
        var searchRange = textLower.startIndex
        
        while let range = textLower.range(of: searchLower, range: searchRange..<textLower.endIndex) {
            if let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString),
               let attributedEndRange = AttributedString.Index(range.upperBound, within: attributedString) {
                let fullRange = attributedRange..<attributedEndRange
                attributedString[fullRange].backgroundColor = .yellow
                attributedString[fullRange].foregroundColor = .black
            }
            
            searchRange = range.upperBound
        }
        
        return attributedString
    }
} 