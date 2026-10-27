import SwiftUI
import WebKit

/// Shows one HTML page. Links within the page (`#anchors`) navigate in place;
/// any other link opens in the default browser.
struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = PageWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.load(html, baseURL: baseURL, into: webView)
        if let baseURL { context.coordinator.watch(baseURL, for: webView) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(html, baseURL: baseURL, into: webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopWatching()
    }

    /// Keeps undo for typing in the page (e.g. a search field) to itself. By
    /// default it would use the document's undo manager, which marks the
    /// read-only document as edited and makes AppKit offer to duplicate it.
    final class PageWebView: WKWebView {
        private let pageUndoManager = UndoManager()
        override var undoManager: UndoManager? { pageUndoManager }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var html: String?
        private var scrollToRestore: Any?
        private var fileURL: URL?
        private weak var webView: WKWebView?
        private var watcher: DispatchSourceFileSystemObject?
        private var pendingReload: DispatchWorkItem?

        /// Reloads the page whenever the file at `url` changes, including when
        /// it is replaced by an atomic save.
        func watch(_ url: URL, for webView: WKWebView) {
            fileURL = url
            self.webView = webView
            startWatcher()
        }

        func stopWatching() {
            pendingReload?.cancel()
            watcher?.cancel()
            watcher = nil
        }

        private func startWatcher() {
            watcher?.cancel()
            watcher = nil
            guard let fileURL else { return }
            let fd = open(fileURL.path, O_EVTONLY)
            guard fd >= 0 else {
                // Mid-replace, or deleted. Look again shortly.
                scheduleReload(after: 1)
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.scheduleReload(after: 0.25) }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            watcher = source
        }

        // Waits briefly so a file being written is read once, after the writer finishes.
        private func scheduleReload(after delay: TimeInterval) {
            pendingReload?.cancel()
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.reloadFromDisk() }
            }
            pendingReload = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        private func reloadFromDisk() {
            guard let fileURL, let webView else { return }
            // An atomic save leaves the old watcher on a deleted file; watch the new one.
            startWatcher()
            guard let data = try? Data(contentsOf: fileURL) else { return }
            load(String(decoding: data, as: UTF8.self), baseURL: fileURL, into: webView)
        }

        /// Loads `html` if it differs from what is showing, keeping the scroll position.
        func load(_ html: String, baseURL: URL?, into webView: WKWebView) {
            guard html != self.html else { return }
            let isReload = self.html != nil
            self.html = html
            guard isReload else {
                webView.loadHTMLString(html, baseURL: baseURL)
                return
            }
            Task {
                scrollToRestore = try? await webView.evaluateJavaScript("[scrollX, scrollY]")
                webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let scroll = scrollToRestore as? [Double], scroll.count == 2 else { return }
            scrollToRestore = nil
            webView.evaluateJavaScript("scrollTo(\(scroll[0]), \(scroll[1]))")
        }

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
