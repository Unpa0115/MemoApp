//
//  MemoAppApp.swift
//  MemoApp
//
//  Created by YujiYamanaka on 2025/06/04.
//

import SwiftUI
import SwiftData

@main
struct MemoAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var navRouter = NavigationRouter()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Tag.self,
            Category.self,
            SubstackAccount.self,
            SMTPService.self,
            ScheduledPost.self,
            SentLog.self,
            Goal.self,
            LinkedNote.self,
            Conversation.self,
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // BGTaskSchedulerの登録をアプリ起動時に行う
        SubstackScheduleService().initializeBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(navRouter)
                .onReceive(NotificationCenter.default.publisher(
                    for: .didReceiveNoteNotification
                )) { notification in
                    guard let noteID = notification.userInfo?["noteID"] as? UUID else { return }
                    navRouter.navigateToNoteEditor(id: noteID)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
