import SwiftData
import Foundation

@Model
class Category: Identifiable {
    @Attribute(.unique) var id: UUID
    
    // カテゴリ名
    var name: String
    
    // 同階層内での表示順（並び替え用）
    var orderIndex: Int
    
    // 親カテゴリ（ルート階層なら nil）
    @Relationship(inverse: \Category.subCategories) var parent: Category?
    
    // 子カテゴリ（階層構造）
    @Relationship var subCategories: [Category]
    
    // このカテゴリに属するノート（多対多関係）
    @Relationship(inverse: \Note.categories) var subNotes: [Note]
    
    init(name: String, orderIndex: Int = 0, parent: Category? = nil) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self.parent = parent
        self.subCategories = []
        self.subNotes = []
    }
} 