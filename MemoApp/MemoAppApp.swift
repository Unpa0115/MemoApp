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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Tag.self,
            Category.self,
            SubstackAccount.self,
            SMTPService.self,
            ScheduledPost.self,
            SentLog.self,
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
        }
        .modelContainer(sharedModelContainer)
    }
}
