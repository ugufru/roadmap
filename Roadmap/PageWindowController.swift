import AppKit
import WebKit

/// The window for one document. Links within the page (`#anchors`) navigate in
/// place; any other link opens in the default browser. The page reloads when
/// its file changes on disk.
final class PageWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private let webView = WKWebView()
    private var html: String?
    private var scrollToRestore: Any?
    private var fileURL: URL?
    private var watcher: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        super.init(window: window)
        window.contentView = webView
        window.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Shows `html`, then reloads it whenever the file at `fileURL` changes,
    /// including when it is replaced by an atomic save.
    func show(_ html: String, fileURL: URL?) {
        load(html)
        self.fileURL = fileURL
        startWatcher()
    }

    func windowWillClose(_ notification: Notification) {
        pendingReload?.cancel()
        watcher?.cancel()
        watcher = nil
    }

    // MARK: Loading

    /// Loads `html` if it differs from what is showing, keeping the scroll position.
    private func load(_ html: String) {
        guard html != self.html else { return }
        let isReload = self.html != nil
        self.html = html
        guard isReload else {
            webView.loadHTMLString(html, baseURL: fileURL)
            return
        }
        Task {
            scrollToRestore = try? await webView.evaluateJavaScript("[scrollX, scrollY]")
            webView.loadHTMLString(html, baseURL: fileURL)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let scroll = scrollToRestore as? [Double], scroll.count == 2 else { return }
        scrollToRestore = nil
        webView.evaluateJavaScript("scrollTo(\(scroll[0]), \(scroll[1]))")
    }

    // MARK: Watching the file

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
        source.setCancelHandler { Darwin.close(fd) }
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
        guard let fileURL else { return }
        // An atomic save leaves the old watcher on a deleted file; watch the new one.
        startWatcher()
        guard let data = try? Data(contentsOf: fileURL) else { return }
        load(String(decoding: data, as: UTF8.self))
    }

    // MARK: Links

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
