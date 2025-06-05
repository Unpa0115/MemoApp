import SwiftUI
import SwiftData
import PhotosUI

struct ScheduledPostFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scheduleService = SubstackScheduleService()
    
    @Query private var accounts: [SubstackAccount]
    @Query private var services: [SMTPService]
    
    @State private var selectedAccount: SubstackAccount?
    @State private var selectedService: SMTPService?
    @State private var title: String = ""
    @State private var contentMarkdown: String = ""
    @State private var includeReadMore: Bool = true
    @State private var scheduledDate: Date = Date().addingTimeInterval(3600) // 1時間後
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var thumbnailData: Data?
    @State private var thumbnailImage: UIImage?
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPreview = false
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本設定セクション
                Section(header: Text("投稿設定")) {
                    Picker("投稿先アカウント", selection: $selectedAccount) {
                        Text("選択してください").tag(Optional<SubstackAccount>.none)
                        ForEach(accounts) { account in
                            Text(account.displayName ?? account.emailAddress)
                                .tag(Optional(account))
                        }
                    }
                    .disabled(accounts.isEmpty)
                    
                    if accounts.isEmpty {
                        Text("Substackアカウントを設定してください")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Picker("SMTPサービス", selection: $selectedService) {
                        Text("選択してください").tag(Optional<SMTPService>.none)
                        ForEach(services) { service in
                            Text(service.serviceName)
                                .tag(Optional(service))
                        }
                    }
                    .disabled(services.isEmpty)
                    
                    if services.isEmpty {
                        Text("SMTPサービスを設定してください")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // 投稿内容セクション
                Section(header: Text("投稿内容")) {
                    TextField("タイトル", text: $title)
                        .font(.headline)
                    
                    NavigationLink(destination: MarkdownEditorView(content: $contentMarkdown)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本文")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if contentMarkdown.isEmpty {
                                Text("本文を入力してください")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(contentMarkdown)
                                    .lineLimit(3)
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: { showingPreview = true }) {
                        Label("プレビュー", systemImage: "eye")
                    }
                    .disabled(contentMarkdown.isEmpty)
                }
                
                // サムネイル設定
                Section(header: Text("サムネイル")) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            if let thumbnailImage = thumbnailImage {
                                Image(uiImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading) {
                                    Text("サムネイル画像")
                                        .font(.headline)
                                    Text("タップして変更")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Label("サムネイル画像を選択", systemImage: "photo")
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newPhoto in
                        loadPhoto(newPhoto)
                    }
                    
                    Toggle("「続きを読む」リンクを挿入", isOn: $includeReadMore)
                }
                
                // 予約設定
                Section(header: Text("投稿予約")) {
                    DatePicker(
                        "投稿日時",
                        selection: $scheduledDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    
                    if scheduledDate <= Date() {
                        Text("未来の日時を選択してください")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // エラーメッセージ
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("予約する") {
                        schedulePost()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .sheet(isPresented: $showingPreview) {
                MarkdownPreviewSheet(content: contentMarkdown, title: title)
            }
        }
    }
    
    private var isFormValid: Bool {
        selectedAccount != nil &&
        selectedService != nil &&
        !title.isEmpty &&
        !contentMarkdown.isEmpty &&
        scheduledDate > Date()
    }
    
    private func loadPhoto(_ photo: PhotosPickerItem?) {
        guard let photo = photo else { return }
        
        Task {
            do {
                if let data = try await photo.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            thumbnailData = data
                            thumbnailImage = image
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "画像の読み込みに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func schedulePost() {
        guard let account = selectedAccount,
              let service = selectedService else { return }
        
        isLoading = true
        errorMessage = nil
        
        let post = ScheduledPost(
            account: account,
            smtpService: service,
            title: title,
            contentMarkdown: contentMarkdown,
            includeReadMore: includeReadMore,
            scheduledDate: scheduledDate
        )
        
        if let thumbnailData = thumbnailData {
            post.thumbnailData = thumbnailData
        }
        
        Task {
            do {
                try await scheduleService.schedulePost(post, context: modelContext)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "予約の作成に失敗しました: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct MarkdownEditorView: View {
    @Binding var content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $content)
                    .font(.body)
                    .padding()
            }
            .navigationTitle("本文編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MarkdownPreviewSheet: View {
    let content: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    MarkdownPreviewView(markdown: content)
                }
                .padding()
            }
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScheduledPostFormView()
        .modelContainer(for: [SubstackAccount.self, SMTPService.self, ScheduledPost.self], inMemory: true)
} 