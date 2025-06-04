import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        NavigationStack {
            List(notes, id: \.id) { note in
                NavigationLink(value: note) {
                    NoteRowView(note: note)
                }
            }
            .navigationTitle("メモ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        // ネットワークステータス表示
                        Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                            .foregroundColor(networkMonitor.isConnected ? .green : .red)
                            .font(.caption)
                        
                        // 新規作成ボタン
                        Button(action: createNewNote) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note)
            }
        }
    }
    
    private func createNewNote() {
        let newNote = Note()
        context.insert(newNote)
        do {
            try context.save()
        } catch {
            print("SwiftData Insert Error: \(error.localizedDescription)")
        }
    }
} 