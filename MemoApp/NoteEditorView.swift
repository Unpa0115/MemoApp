import SwiftUI
import SwiftData
import Combine

struct NoteEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var note: Note
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var content: String = ""
    @State private var autoSaveStatus: AutoSaveStatus = .idle
    @State private var isSplitMode: Bool = false
    @State private var showingPreview: Bool = false
    @State private var isRichMode: Bool = false // リアルタイムMarkdownモード
    
    private let contentSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    init(note: Note) {
        self.note = note
        _content = State(initialValue: note.content)
    }
    
    var body: some View {
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
        .navigationTitle(note.title ?? "（無題）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // ネットワークステータス
                    Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(networkMonitor.isConnected ? .green : .red)
                        .font(.caption)
                    
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
                    
                    // 手動保存ボタン
                    Button(action: manualSave) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
        .onAppear {
            setupAutoSave()
        }
        .onDisappear {
            cancellables.forEach { $0.cancel() }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                manualSave()
            }
        }
        .overlay(saveStatusView, alignment: .topTrailing)
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
                // 通常のテキストエディタ
                TextEditor(text: $content)
                    .font(.body)
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
} 