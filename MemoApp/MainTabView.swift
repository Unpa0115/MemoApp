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
            
            // カテゴリ管理タブ
            CategoryListView()
                .tabItem {
                    Label("カテゴリ", systemImage: "folder")
                }
        }
    }
} 