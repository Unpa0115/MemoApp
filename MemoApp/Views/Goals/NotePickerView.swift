import SwiftUI
import SwiftData

struct NotePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Binding var selectedNotes: [Note]
    let goal: Goal
    
    @State private var searchText = ""
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { note in
                note.title?.localizedCaseInsensitiveContains(searchText) == true ||
                note.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("メモを選択して目標に紐づけてください")) {
                    ForEach(filteredNotes) { note in
                        NotePickerRowView(
                            note: note,
                            isSelected: selectedNotes.contains { $0.id == note.id }
                        ) { isSelected in
                            if isSelected {
                                selectedNotes.append(note)
                            } else {
                                selectedNotes.removeAll { $0.id == note.id }
                            }
                        }
                    }
                }
            }
            .navigationTitle("メモを選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "メモを検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        selectedNotes.removeAll()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .disabled(selectedNotes.isEmpty)
                }
            }
        }
    }
}

struct NotePickerRowView: View {
    let note: Note
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title ?? "（無題）")
                            .font(.headline)
                            .lineLimit(1)
                        
                        if !note.content.isEmpty {
                            Text(note.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var selectedNotes: [Note] = []
    let goal = Goal(name: "テスト目標", frequency: .daily, targetCount: 1)
    
    return NotePickerView(selectedNotes: $selectedNotes, goal: goal)
        .modelContainer(for: [Note.self, Goal.self, LinkedNote.self])
} 