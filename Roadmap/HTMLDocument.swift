import SwiftUI
import UniformTypeIdentifiers

/// An HTML file opened read-only.
struct HTMLDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.html]

    let html: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        html = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(html.utf8))
    }
}
