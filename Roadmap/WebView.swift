import SwiftUI
import WebKit

/// Shows one HTML page. Links within the page (`#anchors`) navigate in place;
/// any other link opens in the default browser.
struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard action.navigationType == .linkActivated,
                  let url = action.request.url,
                  !isSameDocument(url, webView.url) else { return .allow }
            NSWorkspace.shared.open(url)
            return .cancel
        }

        // Links with target="_blank" ask for a new window; send them to the browser.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { NSWorkspace.shared.open(url) }
            return nil
        }

        private func isSameDocument(_ a: URL, _ b: URL?) -> Bool {
            guard let b else { return false }
            return withoutFragment(a) == withoutFragment(b)
        }

        private func withoutFragment(_ url: URL) -> URL? {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            parts?.fragment = nil
            return parts?.url
        }
    }
}
