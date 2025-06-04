import SwiftUI
import SwiftData

// MARK: - Tag Chip View

struct TagChipView: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.caption)
                .lineLimit(1)
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
        )
        .foregroundColor(isSelected ? .white : .primary)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Tag Selection Modal

struct TagSelectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name, order: .forward) private var allTags: [Tag]
    
    @Binding var selectedTags: [Tag]
    @State private var searchText = ""
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return allTags
        }
        return allTags.filter { tag in
            tag.name.localizedStandardContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 検索バー
                TextField("タグを検索…", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // 既存タグリスト
                List {
                    ForEach(filteredTags) { tag in
                        HStack {
                            Text(tag.name)
                            Spacer()
                            if selectedTags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTag(tag)
                        }
                    }
                    
                    // 新規タグ作成ボタン
                    if !searchText.isEmpty && !filteredTags.contains(where: { $0.name.lowercased() == searchText.lowercased() }) {
                        Button(action: createNewTag) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("'\(searchText)' を新規作成")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("タグ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
    
    private func createNewTag() {
        let newTag = Tag(name: searchText)
        context.insert(newTag)
        
        do {
            try context.save()
            selectedTags.append(newTag)
            searchText = ""
        } catch {
            errorMessage = "タグの作成に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Suggested Tags View

struct SuggestedTagsView: View {
    let suggestedTags: [SuggestedTag]
    let onTagSelected: (String) -> Void
    
    var body: some View {
        if !suggestedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("AI推奨タグ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedTags) { suggestion in
                            Button(action: {
                                onTagSelected(suggestion.name)
                            }) {
                                HStack(spacing: 4) {
                                    Text(suggestion.name)
                                        .font(.caption)
                                    Text(String(format: "%.0f%%", suggestion.confidence * 100))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                                )
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Tag Input Field

struct TagInputField: View {
    let onTagAdded: (String) -> Void
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        HStack {
            TextField("新しいタグを入力...", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isInputFocused)
                .onSubmit {
                    addTag()
                }
            
            Button(action: addTag) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private func addTag() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        onTagAdded(trimmedText)
        inputText = ""
        isInputFocused = false
    }
} 