import SwiftUI
import Foundation

class NavigationRouter: ObservableObject {
    @Published var selectedNoteID: UUID?
    @Published var showNoteEditor = false
    @Published var showGoalDetail = false
    @Published var selectedGoal: Goal?
    
    func navigateToNoteEditor(id: UUID) {
        selectedNoteID = id
        showNoteEditor = true
    }
    
    func navigateToGoalDetail(goal: Goal) {
        selectedGoal = goal
        showGoalDetail = true
    }
    
    func dismissNoteEditor() {
        showNoteEditor = false
        selectedNoteID = nil
    }
    
    func dismissGoalDetail() {
        showGoalDetail = false
        selectedGoal = nil
    }
} 