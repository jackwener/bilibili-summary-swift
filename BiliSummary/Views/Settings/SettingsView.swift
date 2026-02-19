import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Login Status
                Section("账号") {
                    if auth.isLoggedIn {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(auth.userName.isEmpty ? "已登录" : auth.userName)
                                    .font(.subheadline)
                                Text("Bilibili 账号已连接")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("注销", role: .destructive) {
                                auth.logout()
                            }
                            .font(.caption)
                        }
                    } else {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundStyle(.gray)
                            Text("未登录")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("登录") {
                                showLogin = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.biliPink)
                        }
                    }
                }

                // AI Settings
                Section("AI 设置") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Base URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://open.bigmodel.cn/api/paas/v4", text: $viewModel.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auth Token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("输入 API Key", text: $viewModel.authToken)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)

                        if !viewModel.maskedToken.isEmpty {
                            Text("当前: \(viewModel.maskedToken)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("模型")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task { await viewModel.loadModels() }
                            } label: {
                                if viewModel.isLoadingModels {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("获取模型列表")
                                    }
                                    .font(.caption)
                                }
                            }
                        }

                        // Show picker of detected models if available
                        if !viewModel.availableModels.isEmpty {
                            Picker("选择模型", selection: $viewModel.selectedModel) {
                                Text("-- 手动输入 --").tag("")
                                ForEach(viewModel.availableModels) { model in
                                    Text(model.id).tag(model.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Always show text field for manual input
                        TextField(Constants.defaultModel, text: $viewModel.selectedModel)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Button {
                        viewModel.saveSettings()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("保存设置")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.biliPink)

                    if let msg = viewModel.saveMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Storage Info
                Section("存储") {
                    HStack {
                        Label("总结目录", systemImage: "folder")
                        Spacer()
                        Text(StorageService.shared.summaryRoot.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("清除所有总结", systemImage: "trash")
                    }
                    .confirmationDialog("确定要清除所有总结吗？此操作不可撤销。", isPresented: $showClearConfirm, titleVisibility: .visible) {
                        Button("清除", role: .destructive) {
                            try? StorageService.shared.clearAllSummaries()
                        }
                    }
                }

                // About
                Section("关于") {
                    HStack {
                        Text("BiliSummary")
                        Spacer()
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/jackwener/bilibili-summary-swift")!) {
                        HStack {
                            Label("源代码", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                viewModel.loadSettings()
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    @State private var showLogin = false
    @State private var showClearConfirm = false
}
