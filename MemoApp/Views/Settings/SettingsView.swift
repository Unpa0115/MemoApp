import SwiftUI

struct SettingsView: View {
    @State private var showAPIKeySettings = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("AI機能") {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("API キー設定")
                                .font(.body)
                            
                            Text(apiKeyStatusText)
                                .font(.caption)
                                .foregroundColor(apiKeyStatusColor)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAPIKeySettings = true
                    }
                    
                    HStack {
                        Image(systemName: "apple.logo")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Intelligence")
                                .font(.body)
                            
                            Text(appleIntelligenceStatusText)
                                .font(.caption)
                                .foregroundColor(appleIntelligenceStatusColor)
                        }
                        
                        Spacer()
                        
                        if AppleIntelligenceService.shared.isAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("アプリについて") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("ライセンス")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("サポート") {
                    Button(action: {
                        if let url = URL(string: "mailto:support@memoapp.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("サポートに連絡")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/yourusername/memoapp") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("GitHub")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
    }
    
    private var apiKeyStatusText: String {
        if KeychainService.shared.hasOpenAIKey() {
            return "設定済み"
        } else {
            return "未設定"
        }
    }
    
    private var apiKeyStatusColor: Color {
        if KeychainService.shared.hasOpenAIKey() {
            return .green
        } else {
            return .orange
        }
    }
    
    private var appleIntelligenceStatusText: String {
        if AppleIntelligenceService.shared.isAvailable {
            return "利用可能（ローカル処理）"
        } else {
            return "iOS 18.1以降が必要"
        }
    }
    
    private var appleIntelligenceStatusColor: Color {
        if AppleIntelligenceService.shared.isAvailable {
            return .green
        } else {
            return .orange
        }
    }
} 