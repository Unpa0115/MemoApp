import SwiftUI
import SwiftData

struct SMTPServiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SMTPService.serviceName, order: .forward)
    private var services: [SMTPService]
    
    @State private var showingAddServiceForm = false
    @State private var editingService: SMTPService?
    
    var body: some View {
        NavigationStack {
            List {
                if services.isEmpty {
                    ContentUnavailableView(
                        "SMTPサービスがありません",
                        systemImage: "envelope.circle",
                        description: Text("メール送信サービスを追加してください")
                    )
                } else {
                    ForEach(services) { service in
                        ServiceRow(service: service) {
                            editingService = service
                        }
                    }
                    .onDelete(perform: deleteServices)
                }
            }
            .navigationTitle("SMTPサービス")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加", systemImage: "plus") {
                        showingAddServiceForm = true
                    }
                }
                
                if !services.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddServiceForm) {
                SMTPServiceFormView()
            }
            .sheet(item: $editingService) { service in
                SMTPServiceFormView(service: service)
            }
        }
    }
    
    private func deleteServices(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let service = services[index]
                modelContext.delete(service)
            }
            
            do {
                try modelContext.save()
            } catch {
                print("サービス削除エラー: \(error.localizedDescription)")
            }
        }
    }
}

struct ServiceRow: View {
    let service: SMTPService
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(service.serviceName)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: service.useTLS ? "lock.fill" : "lock.open")
                    .foregroundColor(service.useTLS ? .green : .orange)
                    .font(.caption)
            }
            
            Text(service.fromEmail)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("\(service.smtpHost):\(service.smtpPort)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("作成日: \(service.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

struct SMTPServiceFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let service: SMTPService?
    
    @State private var serviceName: String = ""
    @State private var apiKey: String = ""
    @State private var smtpHost: String = ""
    @State private var smtpPortString: String = "587"
    @State private var useTLS: Bool = true
    @State private var fromEmail: String = ""
    @State private var fromName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(service: SMTPService? = nil) {
        self.service = service
        if let service = service {
            _serviceName = State(initialValue: service.serviceName)
            _apiKey = State(initialValue: service.apiKey)
            _smtpHost = State(initialValue: service.smtpHost)
            _smtpPortString = State(initialValue: String(service.smtpPort))
            _useTLS = State(initialValue: service.useTLS)
            _fromEmail = State(initialValue: service.fromEmail)
            _fromName = State(initialValue: service.fromName ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("サービス情報")) {
                    TextField("サービス名", text: $serviceName)
                    SecureField("API キー", text: $apiKey)
                }
                
                Section(header: Text("SMTP設定")) {
                    TextField("SMTPホスト", text: $smtpHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("SMTPポート", text: $smtpPortString)
                        .keyboardType(.numberPad)
                    
                    Toggle("TLSを使用", isOn: $useTLS)
                }
                
                Section(header: Text("差出人情報")) {
                    TextField("差出人メールアドレス", text: $fromEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("差出人表示名（任意）", text: $fromName)
                }
                
                Section(header: Text("プリセット")) {
                    Button("SendGrid設定") {
                        applyPreset(.sendGrid)
                    }
                    .foregroundColor(.blue)
                    
                    Button("Mailgun設定") {
                        applyPreset(.mailgun)
                    }
                    .foregroundColor(.blue)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(service == nil ? "新規SMTPサービス" : "SMTP設定編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveService()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !serviceName.isEmpty &&
        !apiKey.isEmpty &&
        !smtpHost.isEmpty &&
        !smtpPortString.isEmpty &&
        !fromEmail.isEmpty &&
        Int(smtpPortString) != nil
    }
    
    private func applyPreset(_ preset: SMTPPreset) {
        switch preset {
        case .sendGrid:
            serviceName = "SendGrid"
            smtpHost = "smtp.sendgrid.net"
            smtpPortString = "587"
            useTLS = true
            
        case .mailgun:
            serviceName = "Mailgun"
            smtpHost = "smtp.mailgun.org"
            smtpPortString = "587"
            useTLS = true
        }
    }
    
    private func saveService() {
        guard validateInput() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let service = service {
                // 編集
                updateExistingService(service)
            } else {
                // 新規作成
                createNewService()
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func updateExistingService(_ service: SMTPService) {
        service.serviceName = serviceName
        service.apiKey = apiKey
        service.smtpHost = smtpHost
        service.smtpPort = Int(smtpPortString) ?? 587
        service.useTLS = useTLS
        service.fromEmail = fromEmail
        service.fromName = fromName.isEmpty ? nil : fromName
    }
    
    private func createNewService() {
        let newService = SMTPService(
            serviceName: serviceName,
            apiKey: apiKey,
            smtpHost: smtpHost,
            smtpPort: Int(smtpPortString) ?? 587,
            useTLS: useTLS,
            fromEmail: fromEmail,
            fromName: fromName.isEmpty ? nil : fromName
        )
        modelContext.insert(newService)
    }
    
    private func validateInput() -> Bool {
        guard !serviceName.isEmpty else {
            errorMessage = "サービス名を入力してください"
            return false
        }
        
        guard !apiKey.isEmpty else {
            errorMessage = "API キーを入力してください"
            return false
        }
        
        guard !smtpHost.isEmpty else {
            errorMessage = "SMTPホストを入力してください"
            return false
        }
        
        guard let port = Int(smtpPortString), port > 0, port <= 65535 else {
            errorMessage = "有効なポート番号を入力してください（1-65535）"
            return false
        }
        
        guard !fromEmail.isEmpty else {
            errorMessage = "差出人メールアドレスを入力してください"
            return false
        }
        
        guard fromEmail.contains("@") && fromEmail.contains(".") else {
            errorMessage = "有効な差出人メールアドレスを入力してください"
            return false
        }
        
        return true
    }
}

enum SMTPPreset {
    case sendGrid
    case mailgun
}

#Preview {
    SMTPServiceListView()
        .modelContainer(for: [SMTPService.self], inMemory: true)
} 