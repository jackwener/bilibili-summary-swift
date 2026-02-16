import SwiftUI
import WebKit

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                WebLoginView(
                    url: auth.loginURL,
                    isLoading: $isLoading,
                    onLoginSuccess: {
                        dismiss()
                    }
                )

                if isLoading {
                    ProgressView("加载中...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("登录 Bilibili")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Web Login View (WKWebView wrapper)

struct WebLoginView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let onLoginSuccess: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebLoginView

        init(_ parent: WebLoginView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                parent.isLoading = false
            }

            // Check if we've been redirected away from login page
            if let url = webView.url, BilibiliAuth.shared.isLoginSuccessURL(url) {
                Task { @MainActor in
                    let success = await BilibiliAuth.shared.extractCredential(from: webView)
                    if success {
                        parent.onLoginSuccess()
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let url = navigationAction.request.url,
               BilibiliAuth.shared.isLoginSuccessURL(url) {
                // Login seems successful, try extracting cookies
                Task { @MainActor in
                    // Give cookies a moment to settle
                    try? await Task.sleep(for: .seconds(1))
                    let success = await BilibiliAuth.shared.extractCredential(from: webView)
                    if success {
                        parent.onLoginSuccess()
                    }
                }
            }
            return .allow
        }
    }
}
