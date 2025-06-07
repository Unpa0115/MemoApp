import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey: String = ""
    @State private var isSecureEntry = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isValidating = false
    @State private var keyStatus: KeyStatus = .unknown
    @State private var isDisplayingMaskedKey = false
    
    enum KeyStatus {
        case unknown
        case valid
        case invalid
        case notSet
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI API キー")) {
                    HStack {
                        Group {
                            if isSecureEntry {
                                SecureField("sk-...", text: $apiKey)
                            } else {
                                TextField("sk-...", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, newValue in
                            // ユーザーが編集したらマスク表示フラグをオフ
                            if isDisplayingMaskedKey && newValue != apiKey {
                                isDisplayingMaskedKey = false
                            }
                        }
                        
                        Button(action: {
                            isSecureEntry.toggle()
                        }) {
                            Image(systemName: isSecureEntry ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isDisplayingMaskedKey {
                        Text("※ セキュリティのため、保存済みのキーは省略表示されています")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // キーステータス表示
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        
                        Spacer()
                        
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("アクション")) {
                    Button(action: saveAPIKey) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("キーを保存")
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating || isDisplayingMaskedKey)
                    
                    Button(action: validateAPIKey) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("キーを検証")
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating || isDisplayingMaskedKey)
                    
                    Button(action: quickTest) {
                        HStack {
                            Image(systemName: "network")
                            Text("簡易テスト")
                        }
                    }
                    .disabled(isValidating)
                    
                    if KeychainService.shared.hasOpenAIKey() {
                        Button(action: clearAndEnterNewKey) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("新しいキーを入力")
                            }
                        }
                        
                        Button(action: deleteAPIKey) {
                            HStack {
                                Image(systemName: "trash")
                                Text("キーを削除")
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("ヘルプ")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI APIキーの取得方法:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("1. https://platform.openai.com にアクセス")
                        Text("2. ログイン後、API Keys セクションに移動")
                        Text("3. 「Create new secret key」をクリック")
                        Text("4. 生成されたキーをコピーして上記に貼り付け")
                        
                        Button("OpenAI プラットフォームを開く") {
                            if let url = URL(string: "https://platform.openai.com/api-keys") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                        
                        #if targetEnvironment(simulator)
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("⚠️ シミュレータ環境での注意:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text("シミュレータではネットワーク接続が制限される場合があります。正確なAPIキー検証には実機でのテストをお勧めします。")
                            .foregroundColor(.orange)
                        #endif
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("API キー設定")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadCurrentKey()
                checkKeyStatus()
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var statusIcon: String {
        switch keyStatus {
        case .unknown:
            return "questionmark.circle"
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "xmark.circle.fill"
        case .notSet:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch keyStatus {
        case .unknown:
            return .secondary
        case .valid:
            return .green
        case .invalid:
            return .red
        case .notSet:
            return .orange
        }
    }
    
    private var statusMessage: String {
        switch keyStatus {
        case .unknown:
            return "ステータス不明"
        case .valid:
            return "有効なAPIキー"
        case .invalid:
            return "無効なAPIキー"
        case .notSet:
            return "APIキーが設定されていません"
        }
    }
    
    private func loadCurrentKey() {
        if KeychainService.shared.hasOpenAIKey() {
            // セキュリティのため、マスク表示
            if let key = KeychainService.shared.getOpenAIKey() {
                apiKey = String(key.prefix(7)) + "..." + String(key.suffix(4))
                isDisplayingMaskedKey = true
            }
        } else {
            apiKey = ""
            isDisplayingMaskedKey = false
        }
    }
    
    private func checkKeyStatus() {
        if KeychainService.shared.hasOpenAIKey() {
            keyStatus = .valid // 簡易チェック
        } else {
            keyStatus = .notSet
        }
    }
    
    private func saveAPIKey() {
        guard !apiKey.isEmpty && !isDisplayingMaskedKey else { return }
        
        // APIキーの基本的なフォーマットチェック
        if !apiKey.hasPrefix("sk-") || apiKey.count < 20 {
            alertTitle = "無効なAPIキー"
            alertMessage = "OpenAI APIキーは「sk-」で始まり、十分な長さが必要です。"
            showAlert = true
            return
        }
        
        let success = KeychainService.shared.saveOpenAIKey(apiKey)
        
        if success {
            alertTitle = "保存完了"
            alertMessage = "APIキーが正常に保存されました。"
            keyStatus = .valid
            loadCurrentKey() // マスク表示に戻す
        } else {
            alertTitle = "保存失敗"
            alertMessage = "APIキーの保存に失敗しました。"
        }
        
        showAlert = true
    }
    
    private func validateAPIKey() {
        guard !apiKey.isEmpty && !isDisplayingMaskedKey else { return }
        
        isValidating = true
        keyStatus = .unknown
        
        // 一時的にAPIキーを設定してテスト
        let originalKey = KeychainService.shared.getOpenAIKey()
        
        Task {
            do {
                let client = AIClient.shared
                
                // 1. ネットワーク接続をテスト（実機のみ）
                #if !targetEnvironment(simulator)
                let networkConnected = await client.testNetworkConnection()
                if !networkConnected {
                    await MainActor.run {
                        keyStatus = .invalid
                        alertTitle = "ネットワークエラー"
                        alertMessage = "インターネット接続を確認してください。OpenAI APIサーバーに接続できません。"
                        showAlert = true
                        isValidating = false
                    }
                    return
                }
                #else
                print("⚠️ シミュレータではネットワーク接続テストをスキップします")
                #endif
                
                // 2. APIキーを設定してテスト
                _ = KeychainService.shared.saveOpenAIKey(apiKey)
                
                // 3. API呼び出しテスト
                try await client.testAPIKey()
                
                await MainActor.run {
                    keyStatus = .valid
                    alertTitle = "検証成功"
                    alertMessage = "APIキーは有効です。OpenAI APIとの通信が正常に行えます。"
                    showAlert = true
                    isValidating = false
                    loadCurrentKey() // マスク表示に戻す
                }
                
            } catch {
                // 元のキーを復元（元のキーがあった場合のみ）
                if let original = originalKey {
                    _ = KeychainService.shared.saveOpenAIKey(original)
                } else {
                    _ = KeychainService.shared.deleteOpenAIKey()
                }
                
                let errorDetails = generateDetailedErrorMessage(error)
                
                await MainActor.run {
                    keyStatus = .invalid
                    alertTitle = "検証失敗"
                    alertMessage = errorDetails
                    showAlert = true
                    isValidating = false
                }
            }
        }
    }
    
    /// 詳細なエラーメッセージを生成
    private func generateDetailedErrorMessage(_ error: Error) -> String {
        var message = "APIキー検証に失敗しました。\n\n"
        
        if let aiError = error as? AIClientError {
            switch aiError {
            case .apiKeyMissing:
                message += "原因: APIキーが設定されていません。"
            case .invalidURL:
                message += "原因: 無効なURLです。"
            case .requestFailed(let underlyingError):
                if let nsError = underlyingError as NSError? {
                    if nsError.domain == "OpenAIError" {
                        message += "原因: \(nsError.localizedDescription)"
                        message += "\n\n💡 ヒント: APIキーが正しいか、OpenAIアカウントに十分なクレジットがあるか確認してください。"
                    } else if nsError.code == -1009 {
                        message += "原因: ネットワーク接続がありません。"
                        message += "\n\n💡 ヒント: WiFiまたはモバイルデータ接続を確認してください。"
                    } else if nsError.code == -1001 {
                        message += "原因: リクエストがタイムアウトしました。"
                        #if targetEnvironment(simulator)
                        message += "\n\n💡 シミュレータでのヒント: シミュレータではネットワーク接続が不安定な場合があります。実機でのテストをお勧めします。"
                        #else
                        message += "\n\n💡 ヒント: ネットワーク接続が安定している時に再試行してください。"
                        #endif
                    } else {
                        message += "原因: ネットワークエラー (\(nsError.code))"
                        message += "\n詳細: \(nsError.localizedDescription)"
                    }
                } else {
                    message += "原因: リクエストエラー\n詳細: \(underlyingError.localizedDescription)"
                }
            case .invalidResponse:
                message += "原因: サーバーから無効なレスポンスを受信しました。"
                message += "\n\n💡 ヒント: OpenAI APIサービスの状態を確認してください。"
            case .decodingFailed(let decodingError):
                message += "原因: レスポンスの解析に失敗しました。"
                message += "\n詳細: \(decodingError.localizedDescription)"
            case .networkUnavailable:
                message += "原因: ネットワークが利用できません。"
            }
        } else {
            message += "原因: 予期しないエラー\n詳細: \(error.localizedDescription)"
        }
        
        return message
    }
    
    private func quickTest() {
        Task {
            await MainActor.run {
                isValidating = true
                alertTitle = "テスト実行中"
                alertMessage = "基本的な接続テストを実行しています..."
                showAlert = true
            }
            
            // 基本的な接続テスト
            let client = AIClient.shared
            let networkResult = await client.testNetworkConnection()
            
            await MainActor.run {
                isValidating = false
                if networkResult {
                    alertTitle = "接続テスト成功"
                    alertMessage = "基本的なネットワーク接続は正常です。\n\nAPI キーが正しい場合、OpenAI API への接続が可能です。"
                } else {
                    alertTitle = "接続テスト失敗"
                    alertMessage = "ネットワーク接続に問題があります。\n\nWiFiまたはモバイルデータ接続を確認してください。"
                }
                showAlert = true
            }
        }
    }
    
    private func clearAndEnterNewKey() {
        apiKey = ""
        isDisplayingMaskedKey = false
        keyStatus = .unknown
    }
    
    private func deleteAPIKey() {
        let success = KeychainService.shared.deleteOpenAIKey()
        
        if success {
            apiKey = ""
            isDisplayingMaskedKey = false
            keyStatus = .notSet
            alertTitle = "削除完了"
            alertMessage = "APIキーが削除されました。"
        } else {
            alertTitle = "削除失敗"
            alertMessage = "APIキーの削除に失敗しました。"
        }
        
        showAlert = true
    }
} 