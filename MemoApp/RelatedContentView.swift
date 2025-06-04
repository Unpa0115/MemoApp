import SwiftUI
import SwiftData
import SafariServices

// MARK: - Related Content View

struct RelatedContentView: View {
    let note: Note
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @StateObject private var aiService = AIService.shared
    @State private var relatedNotes: [RelatedNote] = []
    @State private var references: [Reference] = []
    @State private var isLoadingRelated = false
    @State private var isLoadingReferences = false
    @State private var showingSafari = false
    @State private var selectedURL: URL?
    @State private var selectedNote: Note?
    
    var body: some View {
        VStack(spacing: 16) {
            // 関連メモ候補
            RelatedNotesSection(
                relatedNotes: relatedNotes,
                isLoading: isLoadingRelated,
                onRefresh: fetchRelatedNotes,
                onNoteTapped: { relatedNote in
                    // タイトルで実際のNoteを検索
                    if let foundNote = allNotes.first(where: { $0.title == relatedNote.title }) {
                        selectedNote = foundNote
                    }
                }
            )
            
            // 参考文献候補
            ReferencesSection(
                references: references,
                isLoading: isLoadingReferences,
                onRefresh: fetchReferences,
                onURLTapped: { url in
                    selectedURL = url
                    showingSafari = true
                }
            )
        }
        .onAppear {
            fetchRelatedNotes()
            fetchReferences()
        }
        .fullScreenCover(isPresented: $showingSafari) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
        .background {
            if let selectedNote = selectedNote {
                NavigationLink(destination: NoteEditorView(note: selectedNote)) {
                    EmptyView()
                }
                .hidden()
                .onAppear {
                    self.selectedNote = nil
                }
            }
        }
    }
    
    private func fetchRelatedNotes() {
        guard !note.content.isEmpty else { return }
        
        isLoadingRelated = true
        Task {
            let results = await aiService.suggestRelatedNotes(for: note.id, content: note.content)
            await MainActor.run {
                relatedNotes = results
                isLoadingRelated = false
            }
        }
    }
    
    private func fetchReferences() {
        guard !note.content.isEmpty else { return }
        
        isLoadingReferences = true
        Task {
            let results = await aiService.searchReferences(for: note.content)
            await MainActor.run {
                references = results
                isLoadingReferences = false
            }
        }
    }
}

// MARK: - Related Notes Section

struct RelatedNotesSection: View {
    let relatedNotes: [RelatedNote]
    let isLoading: Bool
    let onRefresh: () -> Void
    let onNoteTapped: (RelatedNote) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("関連メモ候補", systemImage: "doc.on.doc")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("関連メモを検索中…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if relatedNotes.isEmpty {
                Text("関連メモが見つかりませんでした")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(relatedNotes) { relatedNote in
                        RelatedNoteRowView(relatedNote: relatedNote)
                            .onTapGesture {
                                onNoteTapped(relatedNote)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Related Note Row View

struct RelatedNoteRowView: View {
    let relatedNote: RelatedNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(relatedNote.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<scoreStars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                    }
                    ForEach(0..<(5 - scoreStars), id: \.self) { _ in
                        Image(systemName: "star")
                            .foregroundColor(.gray)
                            .font(.caption2)
                    }
                }
            }
            
            Text(relatedNote.excerpt)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var scoreStars: Int {
        max(1, min(5, Int(relatedNote.score * 5)))
    }
}

// MARK: - References Section

struct ReferencesSection: View {
    let references: [Reference]
    let isLoading: Bool
    let onRefresh: () -> Void
    let onURLTapped: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("参考文献候補", systemImage: "globe")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("参考文献を検索中…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if references.isEmpty {
                VStack(spacing: 8) {
                    Text("参考文献を検索するには")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("検索を開始", action: onRefresh)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(references) { reference in
                        ReferenceRowView(
                            reference: reference,
                            onTapped: { onURLTapped(reference.url) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Reference Row View

struct ReferenceRowView: View {
    let reference: Reference
    let onTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reference.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .lineLimit(2)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            Text(reference.snippet)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Text(reference.url.host ?? reference.url.absoluteString)
                .font(.caption2)
                .foregroundColor(.green)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture(perform: onTapped)
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
} 