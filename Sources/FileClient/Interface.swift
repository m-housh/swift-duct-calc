import Dependencies
import DependenciesMacros
import Foundation

extension DependencyValues {
  public var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

@DependencyClient
public struct FileClient: Sendable {
  public var writeFile: @Sendable (String, String) async throws -> Void
  public var removeFile: @Sendable (String) async throws -> Void
}

extension FileClient: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    writeFile: { contents, path in
      try contents.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    },
    removeFile: { path in
      try FileManager.default.removeItem(atPath: path)
    }
  )
}
