import Dependencies
import DependenciesMacros
import Foundation
import Vapor

extension DependencyValues {
  /// Dependency used for file operations.
  public var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

@DependencyClient
public struct FileClient: Sendable {
  public typealias OnCompleteHandler = @Sendable () async throws -> Void

  /// Write contents to a file.
  ///
  /// > Warning: This will overwrite a file if it exists.
  public var writeFile: @Sendable (_ contents: String, _ path: String) async throws -> Void

  /// Read contents of file.
  public var readFile: @Sendable (_ path: String) async throws -> Data

  /// Remove a file.
  public var removeFile: @Sendable (_ path: String) async throws -> Void
  /// Stream a file.
  public var streamFile:
    @Sendable (_ path: String, @escaping OnCompleteHandler) async throws -> Response

  /// Stream a file at the given path.
  ///
  /// - Paramters:
  ///   - path: The path to the file to stream.
  ///   - onComplete: Completion handler to run when done streaming the file.
  public func streamFile(
    at path: String,
    onComplete: @escaping OnCompleteHandler = {}
  ) async throws -> Response {
    try await streamFile(path, onComplete)
  }
}

extension FileClient: TestDependencyKey {
  public static let testValue = Self()

  public static func live(fileIO: FileIO) -> Self {
    .init(
      writeFile: { contents, path in
        try await fileIO.writeFile(ByteBuffer(string: contents), at: path)
      },
      readFile: { path in
        let bytes = try await fileIO.collectFile(at: path)
        return Data(buffer: bytes)
      },
      removeFile: { path in
        try FileManager.default.removeItem(atPath: path)
      },
      streamFile: { path, onComplete in
        try await fileIO.asyncStreamFile(at: path) { _ in
          try await onComplete()
        }
      }
    )
  }
}
