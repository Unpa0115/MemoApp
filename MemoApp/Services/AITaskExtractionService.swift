import Foundation

class AITaskExtractionService: ObservableObject {
    static let shared = AITaskExtractionService()
    
    private init() {}
    
    // AI タスク抽出関数
    func extractTasksForNote(_ note: Note) async {
        // TODO: 実際のAI APIエンドポイントに置き換える
        guard let url = URL(string: "https://api.example.com/api/v1/extract_tasks") else {
            // デモ用のモックレスポンス
            await generateMockTasks(for: note)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "noteId": note.id.uuidString,
            "content": note.content,
            "language": "ja"
        ]
        
        do {
            let body = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = body
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
                print("AI タスク抽出: レスポンス異常")
                await generateMockTasks(for: note)
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let aiResponse = try decoder.decode(AIResponse.self, from: data)
            
            let tasks = aiResponse.tasks.map { AITask(
                description: $0.description,
                suggestedDate: $0.suggestedDate
            ) }
            
            await MainActor.run {
                note.aiSuggestedTasks = tasks
                // View が aiSuggestedTasks の変更を検知して再描画される
            }
        } catch {
            print("AI タスク抽出エラー: \(error.localizedDescription)")
            await generateMockTasks(for: note)
        }
    }
    
    // デモ用のモックタスク生成
    private func generateMockTasks(for note: Note) async {
        let mockTasks = extractTasksFromContent(note.content)
        
        await MainActor.run {
            note.aiSuggestedTasks = mockTasks
        }
    }
    
    // コンテンツからタスクっぽいものを抽出する簡単なロジック
    private func extractTasksFromContent(_ content: String) -> [AITask] {
        let lines = content.components(separatedBy: .newlines)
        var tasks: [AITask] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // TODOマーカーを探す
            if trimmed.lowercased().contains("todo") ||
               trimmed.lowercased().contains("やること") ||
               trimmed.lowercased().contains("タスク") ||
               trimmed.contains("□") ||
               trimmed.contains("☐") ||
               trimmed.hasPrefix("- [ ]") ||
               trimmed.hasPrefix("* [ ]") {
                
                let description = trimmed
                    .replacingOccurrences(of: "TODO:", with: "")
                    .replacingOccurrences(of: "todo:", with: "")
                    .replacingOccurrences(of: "やること:", with: "")
                    .replacingOccurrences(of: "タスク:", with: "")
                    .replacingOccurrences(of: "□", with: "")
                    .replacingOccurrences(of: "☐", with: "")
                    .replacingOccurrences(of: "- [ ]", with: "")
                    .replacingOccurrences(of: "* [ ]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !description.isEmpty {
                    tasks.append(AITask(
                        description: description,
                        suggestedDate: determineSuggestedDate(from: description)
                    ))
                }
            }
        }
        
        return tasks
    }
    
    // 簡単な日付推定ロジック
    private func determineSuggestedDate(from description: String) -> Date? {
        let today = Date()
        let calendar = Calendar.current
        
        if description.lowercased().contains("今日") || description.lowercased().contains("today") {
            return calendar.date(byAdding: .hour, value: 2, to: today) // 2時間後
        } else if description.lowercased().contains("明日") || description.lowercased().contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        } else if description.lowercased().contains("来週") || description.lowercased().contains("next week") {
            return calendar.date(byAdding: .day, value: 7, to: today)
        } else if description.lowercased().contains("緊急") || description.lowercased().contains("urgent") {
            return calendar.date(byAdding: .hour, value: 1, to: today) // 1時間後
        }
        
        return nil
    }
}

// レスポンス構造体
struct AIResponse: Decodable {
    struct TaskItem: Decodable {
        let description: String
        let suggestedDate: Date?
    }
    let tasks: [TaskItem]
} 