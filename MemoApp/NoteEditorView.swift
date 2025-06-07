import SwiftUI
import SwiftData
import Combine

struct NoteEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var note: Note
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var aiService = AIService.shared
    
    @State private var content: String = ""
    @State private var autoSaveStatus: AutoSaveStatus = .idle
    @State private var isSplitMode: Bool = false
    @State private var showingPreview: Bool = false
    @State private var isRichMode: Bool = false // リアルタイムMarkdownモード
    @State private var selectedTab: EditorTab = .editor
    
    // タグ関連
    @State private var showingTagSelection = false
    @State private var suggestedTags: [SuggestedTag] = []
    @State private var isLoadingSuggestions = false
    
    // カテゴリ関連
    @State private var showingCategorySelection = false
    
    // AIアシスタント関連
    @State private var showAISheet = false
    @State private var showRewriteSheet = false
    @State private var showQualityCheckSheet = false
    
    private let contentSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    enum EditorTab: String, CaseIterable {
        case editor = "編集"
        case related = "関連"
        case metadata = "情報"
    }
    
    init(note: Note) {
        self.note = note
        _content = State(initialValue: note.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // タブビュー
            TabView(selection: $selectedTab) {
                // 編集タブ
                editorTabContent
                    .tabItem {
                        Label("編集", systemImage: "square.and.pencil")
                    }
                    .tag(EditorTab.editor)
                
                // 関連コンテンツタブ
                relatedTabContent
                    .tabItem {
                        Label("関連", systemImage: "doc.on.doc")
                    }
                    .tag(EditorTab.related)
                
                // メタデータタブ
                metadataTabContent
                    .tabItem {
                        Label("情報", systemImage: "info.circle")
                    }
                    .tag(EditorTab.metadata)
            }
        }
        .navigationTitle(note.title ?? "（無題）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // ネットワークステータス
                    Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(networkMonitor.isConnected ? .green : .red)
                        .font(.caption)
                    
                    if selectedTab == .editor {
                        // AIアシスタントボタン
                        Menu {
                            Button("AIアシスタント") {
                                showAISheet = true
                            }
                            Divider()
                            Button("翻訳・言い換え") {
                                showRewriteSheet = true
                            }
                            Button("品質チェック") {
                                showQualityCheckSheet = true
                            }
                            Divider()
                            NavigationLink("会話型メモ") {
                                ChatNoteEditorView(note: note)
                            }
                        } label: {
                            Image(systemName: "brain")
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("AIアシスタント")
                        
                        // リアルタイムMarkdownトグルボタン
                        Button(action: toggleRichMode) {
                            Image(systemName: isRichMode ? "textformat.abc.dottedunderline" : "textformat")
                                .foregroundColor(isRichMode ? .purple : .primary)
                        }
                        
                        // プレビュートグルボタン
                        Button(action: togglePreview) {
                            Image(systemName: showingPreview ? "square.and.pencil" : "eye")
                        }
                        
                        // 分割モードトグルボタン
                        Button(action: toggleSplitMode) {
                            Image(systemName: isSplitMode ? "rectangle" : "rectangle.split.2x1")
                        }
                    }
                    
                    // 手動保存ボタン
                    Button(action: manualSave) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
        .onAppear {
            setupAutoSave()
            fetchTagSuggestions()
        }
        .onDisappear {
            cancellables.forEach { $0.cancel() }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                manualSave()
            }
        }
        .onChange(of: content) { oldText, newText in
            if oldText != newText {
                fetchTagSuggestions()
            }
        }
        .overlay(saveStatusView, alignment: .topTrailing)
        .sheet(isPresented: $showingTagSelection) {
            TagSelectionView(selectedTags: $note.tags)
        }
        .sheet(isPresented: $showingCategorySelection) {
            CategorySelectionView(selectedCategories: $note.categories)
        }
        .sheet(isPresented: $showAISheet) {
            AISheetView(note: note, isPresented: $showAISheet)
        }
        .sheet(isPresented: $showRewriteSheet) {
            RewriteView(note: note, isPresented: $showRewriteSheet)
        }
        .sheet(isPresented: $showQualityCheckSheet) {
            QualityCheckView(note: note, isPresented: $showQualityCheckSheet)
        }
    }
    
    // MARK: - Tab Content Views
    
    private var editorTabContent: some View {
        VStack(spacing: 0) {
            if isSplitMode {
                splitView
            } else {
                if showingPreview {
                    previewOnlyView
                } else {
                    editorOnlyView
                }
            }
        }
    }
    
    private var relatedTabContent: some View {
        ScrollView {
            RelatedContentView(note: note)
                .padding()
        }
    }
    
    private var metadataTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // タグセクション
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("タグ")
                            .font(.headline)
                        Spacer()
                        Button("管理") {
                            showingTagSelection = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    // タグ直接入力フィールド
                    TagInputField(
                        onTagAdded: { tagName in
                            addTag(tagName)
                        }
                    )
                    
                    // 現在のタグ表示
                    if note.tags.isEmpty {
                        Text("タグが設定されていません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.tags, id: \.id) { tag in
                                    TagChipView(
                                        tag: tag,
                                        isSelected: false,
                                        onTap: { },
                                        onDelete: {
                                            removeTag(tag)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // AI推奨タグ
                    SuggestedTagsView(
                        suggestedTags: suggestedTags,
                        onTagSelected: { tagName in
                            addSuggestedTag(tagName)
                        }
                    )
                }
                
                Divider()
                
                // カテゴリセクション
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("カテゴリ")
                            .font(.headline)
                        Spacer()
                        Button("管理") {
                            showingCategorySelection = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    // 現在のカテゴリ表示
                    if note.categories.isEmpty {
                        Text("カテゴリが設定されていません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.categories, id: \.id) { category in
                                    CategoryChipView(
                                        category: category,
                                        onRemove: {
                                            removeCategory(category)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                
                // リマインダーセクション
                VStack(alignment: .leading, spacing: 8) {
                    Text("リマインダー")
                        .font(.headline)
                    
                    ReminderSectionView(note: note)
                }
                
                Divider()
                
                // AIタスク提案セクション
                VStack(alignment: .leading, spacing: 8) {
                    AITaskSuggestionView(note: note)
                }
                
                Divider()
                
                // メタ情報
                VStack(alignment: .leading, spacing: 8) {
                    Text("メタ情報")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("作成日時")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("更新日時")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("文字数")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(content.count)文字")
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("行数")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(content.components(separatedBy: .newlines).count)行")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - View Components
    
    private var editorOnlyView: some View {
        Group {
            if isRichMode {
                // リアルタイムMarkdownエディタ
                RichMarkdownEditor(text: $content) { newText in
                    autoSaveStatus = .saving
                    contentSubject.send(newText)
                }
                .padding()
            } else {
                // 通常のテキストエディタ（Apple Intelligence Writing Tools対応）
                TextEditor(text: $content)
                    .font(.body)
                    .writingToolsBehavior(.complete) // Apple Intelligence機能を有効化
                    .onChange(of: content) { oldText, newText in
                        autoSaveStatus = .saving
                        contentSubject.send(newText)
                    }
                    .padding()
            }
        }
    }
    
    private var previewOnlyView: some View {
        MarkdownPreviewView(markdown: content)
    }
    
    private var splitView: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // 横向き - 左右分割
                HStack(spacing: 0) {
                    editorOnlyView
                        .frame(width: geometry.size.width / 2)
                    
                    Divider()
                    
                    previewOnlyView
                        .frame(width: geometry.size.width / 2)
                }
            } else {
                // 縦向き - 上下分割
                VStack(spacing: 0) {
                    editorOnlyView
                        .frame(height: geometry.size.height / 2)
                    
                    Divider()
                    
                    previewOnlyView
                        .frame(height: geometry.size.height / 2)
                }
            }
        }
    }
    
    @ViewBuilder
    private var saveStatusView: some View {
        switch autoSaveStatus {
        case .saving:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("保存中...")
                    .font(.caption)
            }
            .padding(8)
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(8)
            .padding()
            
        case .success:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("保存完了")
                    .font(.caption)
            }
            .padding(8)
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(8)
            .padding()
            
        case .failed:
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("保存失敗")
                    .font(.caption)
            }
            .padding(8)
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(8)
            .padding()
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Actions
    
    private func togglePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingPreview.toggle()
            if showingPreview {
                isRichMode = false
            }
        }
    }
    
    private func toggleSplitMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSplitMode.toggle()
            if isSplitMode {
                showingPreview = false
            }
        }
    }
    
    private func toggleRichMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isRichMode.toggle()
        }
    }
    
    private func setupAutoSave() {
        contentSubject
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { newText in
                performSave(with: newText)
            }
            .store(in: &cancellables)
    }
    
    private func manualSave() {
        performSave(with: content)
    }
    
    private func performSave(with newContent: String) {
        note.content = newContent
        note.extractTitle()
        note.updatedAt = Date()
        
        do {
            try context.save()
            
            // リマインダーのスケジューリング
            ReminderService.shared.scheduleReminderIfNeeded(for: note)
            
            // 目標への自動連携
            GoalAutoLinkService.shared.autoLinkNoteToGoals(note, context: context)
            
            autoSaveStatus = .success
            
            // 1秒後にステータスをリセット
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if autoSaveStatus == .success {
                    autoSaveStatus = .idle
                }
            }
        } catch {
            print("SwiftData Save Error: \(error.localizedDescription)")
            autoSaveStatus = .failed
            
            // 3秒後にステータスをリセット
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if autoSaveStatus == .failed {
                    autoSaveStatus = .idle
                }
            }
        }
    }
    
    // MARK: - Tag Management
    
    private func fetchTagSuggestions() {
        guard !content.isEmpty else { return }
        
        isLoadingSuggestions = true
        Task {
            let suggestions = await aiService.suggestTags(for: content)
            await MainActor.run {
                suggestedTags = suggestions
                isLoadingSuggestions = false
            }
        }
    }
    
    private func addSuggestedTag(_ tagName: String) {
        // 既存のタグを確認
        if let existingTag = findExistingTag(named: tagName) {
            if !note.tags.contains(where: { $0.id == existingTag.id }) {
                note.tags.append(existingTag)
                saveNote()
            }
        } else {
            // 新しいタグを作成
            let newTag = Tag(name: tagName)
            context.insert(newTag)
            note.tags.append(newTag)
            saveNote()
        }
        
        // 推奨リストから削除
        suggestedTags.removeAll { $0.name == tagName }
    }
    
    private func addTag(_ tagName: String) {
        // 空のタグ名は無視
        guard !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 既存のタグを確認
        if let existingTag = findExistingTag(named: trimmedName) {
            if !note.tags.contains(where: { $0.id == existingTag.id }) {
                note.tags.append(existingTag)
                saveNote()
            }
        } else {
            // 新しいタグを作成
            let newTag = Tag(name: trimmedName)
            context.insert(newTag)
            note.tags.append(newTag)
            saveNote()
        }
    }
    
    private func removeTag(_ tag: Tag) {
        note.tags.removeAll { $0.id == tag.id }
        saveNote()
    }
    
    private func removeCategory(_ category: Category) {
        note.categories.removeAll { $0.id == category.id }
        saveNote()
    }
    
    private func findExistingTag(named tagName: String) -> Tag? {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.name == tagName }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func saveNote() {
        do {
            try context.save()
            
            // リマインダーのスケジューリング
            ReminderService.shared.scheduleReminderIfNeeded(for: note)
            
            // 目標への自動連携
            GoalAutoLinkService.shared.autoLinkNoteToGoals(note, context: context)
        } catch {
            print("Failed to save note: \(error)")
        }
    }
} 