import SwiftUI
import SwiftData

struct SubstackAccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubstackAccount.emailAddress, order: .forward)
    private var accounts: [SubstackAccount]
    
    @State private var showingAddAccountForm = false
    @State private var editingAccount: SubstackAccount?
    
    var body: some View {
        NavigationStack {
            List {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "アカウントがありません",
                        systemImage: "person.circle",
                        description: Text("Substackアカウントを追加してください")
                    )
                } else {
                    ForEach(accounts) { account in
                        AccountRow(account: account) {
                            editingAccount = account
                        }
                    }
                    .onDelete(perform: deleteAccounts)
                }
            }
            .navigationTitle("Substackアカウント")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加", systemImage: "plus") {
                        showingAddAccountForm = true
                    }
                }
                
                if !accounts.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddAccountForm) {
                SubstackAccountFormView()
            }
            .sheet(item: $editingAccount) { account in
                SubstackAccountFormView(account: account)
            }
        }
    }
    
    private func deleteAccounts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let account = accounts[index]
                modelContext.delete(account)
            }
            
            do {
                try modelContext.save()
            } catch {
                print("アカウント削除エラー: \(error.localizedDescription)")
            }
        }
    }
}

struct AccountRow: View {
    let account: SubstackAccount
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.displayName ?? account.emailAddress)
                .font(.headline)
            
            if account.displayName != nil {
                Text(account.emailAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("作成日: \(account.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

struct SubstackAccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let account: SubstackAccount?
    
    @State private var emailAddress: String = ""
    @State private var displayName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(account: SubstackAccount? = nil) {
        self.account = account
        if let account = account {
            _emailAddress = State(initialValue: account.emailAddress)
            _displayName = State(initialValue: account.displayName ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("アカウント情報")) {
                    TextField("メールアドレス", text: $emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("表示名（任意）", text: $displayName)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(account == nil ? "新規アカウント" : "アカウント編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAccount()
                    }
                    .disabled(emailAddress.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func saveAccount() {
        guard validateInput() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let account = account {
                // 編集
                account.emailAddress = emailAddress
                account.displayName = displayName.isEmpty ? nil : displayName
            } else {
                // 新規作成
                let newAccount = SubstackAccount(
                    emailAddress: emailAddress,
                    displayName: displayName.isEmpty ? nil : displayName
                )
                modelContext.insert(newAccount)
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func validateInput() -> Bool {
        guard !emailAddress.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            return false
        }
        
        guard emailAddress.contains("@") && emailAddress.contains(".") else {
            errorMessage = "有効なメールアドレスを入力してください"
            return false
        }
        
        return true
    }
}

#Preview {
    SubstackAccountListView()
        .modelContainer(for: [SubstackAccount.self], inMemory: true)
} 