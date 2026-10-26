import SwiftUI

@main
struct RoadmapApp: App {
    var body: some Scene {
        // A viewer-only document app: File > Open, Open Recent and Close come
        // from DocumentGroup; there is no New or Save.
        DocumentGroup(viewing: HTMLDocument.self) { file in
            WebView(html: file.document.html, baseURL: file.fileURL)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}
