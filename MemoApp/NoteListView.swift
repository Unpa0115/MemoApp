import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var searchText = ""
    @State private var showingNewNote = false
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes
        }
        return notes.filter { note in
            (note.title?.localizedStandardContains(searchText) == true) ||
            note.content.localizedStandardContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if filteredNotes.isEmpty {
                    ContentUnavailableView(
                        "メモがありません",
                        systemImage: "note.text",
                        description: Text("新しいメモを作成してください")
                    )
                } else {
                    List {
                        ForEach(filteredNotes) { note in
                            NavigationLink(value: note) {
                                NoteRowView(note: note)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                    .searchable(text: $searchText, prompt: "メモを検索...")
                }
            }
            .navigationTitle("メモ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addNote) {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note)
            }
        }
    }
    
    private func addNote() {
        let newNote = Note()
        context.insert(newNote)
        do {
            try context.save()
        } catch {
            print("Failed to save new note: \(error)")
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredNotes[index])
        }
        do {
            try context.save()
        } catch {
            print("Failed to delete notes: \(error)")
        }
    }
} 