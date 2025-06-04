import Foundation

// MARK: - Data Models

struct SuggestedTag: Identifiable, Codable {
    var id = UUID()
    let name: String
    let confidence: Double
}

struct RelatedNote: Identifiable, Codable {
    var id = UUID()
    let title: String
    let excerpt: String
    let score: Double
}

struct Reference: Identifiable, Codable {
    var id = UUID()
    let title: String
    let snippet: String
    let url: URL
}

// MARK: - AI Service

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    private init() {}
    
    // MARK: - Tag Suggestion
    
    func suggestTags(for content: String) async -> [SuggestedTag] {
        // TODO: 実際のAI APIとの連携を実装
        // 現在はモックデータを返します
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let mockTags = [
                    SuggestedTag(name: "アイデア", confidence: 0.92),
                    SuggestedTag(name: "TODO", confidence: 0.85),
                    SuggestedTag(name: "学習", confidence: 0.78)
                ]
                continuation.resume(returning: mockTags)
            }
        }
    }
    
    // MARK: - Related Notes Suggestion
    
    func suggestRelatedNotes(for noteId: UUID, content: String) async -> [RelatedNote] {
        // TODO: 実際のAI APIとの連携を実装
        // 現在はモックデータを返します
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                let mockRelatedNotes = [
                    RelatedNote(
                        title: "関連メモ1",
                        excerpt: "このメモは関連する内容を含んでいます...",
                        score: 0.87
                    ),
                    RelatedNote(
                        title: "関連メモ2", 
                        excerpt: "似たようなトピックについて書かれています...",
                        score: 0.82
                    )
                ]
                continuation.resume(returning: mockRelatedNotes)
            }
        }
    }
    
    // MARK: - Reference Search
    
    func searchReferences(for content: String) async -> [Reference] {
        // TODO: Google Custom Search APIやBing Web Search APIとの連携を実装
        // 現在はモックデータを返します
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                let mockReferences = [
                    Reference(
                        title: "SwiftUI公式ドキュメント",
                        snippet: "SwiftUIを使ったアプリ開発のガイド",
                        url: URL(string: "https://developer.apple.com/documentation/swiftui")!
                    ),
                    Reference(
                        title: "SwiftData入門",
                        snippet: "SwiftDataの基本的な使い方を学ぶ",
                        url: URL(string: "https://developer.apple.com/documentation/swiftdata")!
                    )
                ]
                continuation.resume(returning: mockReferences)
            }
        }
    }
} 