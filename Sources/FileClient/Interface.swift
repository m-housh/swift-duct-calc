import Dependencies
import DependenciesMacros
import Foundation
import Vapor

extension DependencyValues {
  public var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

@DependencyClient
public struct FileClient: Sendable {
  public typealias OnCompleteHandler = @Sendable () async throws -> Void

  public var writeFile: @Sendable (String, String) async throws -> Void
  public var removeFile: @Sendable (String) async throws -> Void
  public var streamFile: @Sendable (String, @escaping OnCompleteHandler) async throws -> Response
}

extension FileClient: TestDependencyKey {
  public static let testValue = Self()

  public static func live(fileIO: FileIO) -> Self {
    .init(
      writeFile: { contents, path in
        try await fileIO.writeFile(ByteBuffer(string: contents), at: path)
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
