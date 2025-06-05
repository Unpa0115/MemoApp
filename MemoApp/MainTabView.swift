import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // メモ一覧タブ
            NoteListView()
                .tabItem {
                    Label("メモ", systemImage: "note.text")
                }
            
            // 検索タブ
            SearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
            
            // ダッシュボードタブ
            DashboardView()
                .tabItem {
                    Label("ダッシュボード", systemImage: "chart.bar.fill")
                }
            
            // 目標管理タブ
            GoalListView()
                .tabItem {
                    Label("目標", systemImage: "target")
                }
            
            // Substackタブ
            SubstackMainView()
                .tabItem {
                    Label("Substack", systemImage: "paperplane.circle")
                }
            
            // カテゴリ管理タブ
            CategoryListView()
                .tabItem {
                    Label("カテゴリ", systemImage: "folder")
                }
        }
    }
} 