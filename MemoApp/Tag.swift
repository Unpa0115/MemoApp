import SwiftData
import Foundation

@Model
class Tag: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    
    // タグ名（重複不可）
    @Attribute(.unique) var name: String
    
    // 任意で色コードを保持（表示用）
    var colorHex: String?
    
    // 関連ノートとの多対多リレーション
    @Relationship(inverse: \Note.tags) var notes: [Note]
    
    init(name: String, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.notes = []
    }
    
    // Hashableプロトコルの実装
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 