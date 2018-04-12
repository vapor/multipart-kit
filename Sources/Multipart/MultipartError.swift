import Debugging

/// Errors that can be thrown while working with Multipart.
public struct MultipartError: Debuggable {
    /// See `Debuggable`.
    public static let readableName = "Multipart Error"

    /// See `Debuggable`.
    public let identifier: String

    /// See `Debuggable`.
    public var reason: String

    /// See `Debuggable`.
    public var sourceLocation: SourceLocation?

    /// See `Debuggable`.
    public var stackTrace: [String]

    /// Creates a new `MultipartError`.
    public init(identifier: String, reason: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = MultipartError.makeStackTrace()
    }
}
