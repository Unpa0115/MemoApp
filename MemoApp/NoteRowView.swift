import SwiftUI

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title ?? "（無題）")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if note.isDraft {
                    Image(systemName: "pencil")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            Text(formattedUpdatedAt)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private var formattedUpdatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: note.updatedAt)
    }
} 