import Foundation

/// One part of a `multipart/form-data` body.
public struct MultipartPart: Sendable {

    /// The form field name.
    public let name: String

    /// The filename reported for file parts, or `nil` for plain fields.
    public let filename: String?

    /// The part's MIME type, e.g. `"image/jpeg"`.
    public let mimeType: String

    /// The part's payload.
    public let data: Data

    /// Creates a multipart part.
    /// - Parameters:
    ///   - name: The form field name.
    ///   - filename: The filename for file parts. Defaults to `nil`.
    ///   - mimeType: The part's MIME type. Defaults to `"application/octet-stream"`.
    ///   - data: The part's payload.
    public init(
        name: String,
        filename: String? = nil,
        mimeType: String = "application/octet-stream",
        data: Data
    ) {
        self.name = name
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }

    /// A plain text field (`text/plain`, UTF-8).
    /// - Parameters:
    ///   - name: The form field name.
    ///   - value: The field's text.
    public static func text(name: String, value: String) -> MultipartPart {
        MultipartPart(name: name, mimeType: "text/plain", data: Data(value.utf8))
    }

    /// A file part with an explicit filename and content type.
    /// - Parameters:
    ///   - name: The form field name.
    ///   - filename: The filename reported to the server.
    ///   - contentType: The file's MIME type.
    ///   - data: The file's bytes.
    public static func file(name: String, filename: String, contentType: String, data: Data) -> MultipartPart {
        MultipartPart(name: name, filename: filename, mimeType: contentType, data: data)
    }
}
