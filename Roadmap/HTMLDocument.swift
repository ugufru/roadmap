import AppKit

/// An HTML file opened read-only. A viewer never has changes to save, so it
/// never asks anything on close or quit.
@objc(HTMLDocument)
final class HTMLDocument: NSDocument {
    // Set once by read(from:ofType:), which AppKit calls before making windows.
    nonisolated(unsafe) private var html = ""

    override init() {
        super.init()
        // Typing in the page (e.g. a search field) must not count as an edit.
        hasUndoManager = false
    }

    override class var autosavesInPlace: Bool { false }
    override class var writableTypes: [String] { [] }
    override var isDocumentEdited: Bool { false }
    override func updateChangeCount(_ change: NSDocument.ChangeType) {}

    override func read(from data: Data, ofType typeName: String) throws {
        html = String(decoding: data, as: UTF8.self)
    }

    override func makeWindowControllers() {
        let controller = PageWindowController()
        addWindowController(controller)
        controller.show(html, fileURL: fileURL)
    }
}
