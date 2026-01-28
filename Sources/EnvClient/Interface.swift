import Dependencies
import DependenciesMacros
import Foundation

extension DependencyValues {

  /// Holds values defined in the process environment that are needed.
  ///
  /// These are generally loaded from a `.env` file, but also have default values,
  /// if not found.
  public var env: @Sendable () throws -> EnvVars {
    get { self[EnvClient.self].env }
    set { self[EnvClient.self].env = newValue }
  }
}

@DependencyClient
struct EnvClient: Sendable {

  public var env: @Sendable () throws -> EnvVars
}

public struct EnvVars: Codable, Equatable, Sendable {

  public let pandocPath: String
  public let pdfEngine: String

  public init(
    pandocPath: String = "/bin/pandoc",
    pdfEngine: String = "weasyprint"
  ) {
    self.pandocPath = pandocPath
    self.pdfEngine = pdfEngine
  }

  enum CodingKeys: String, CodingKey {
    case pandocPath = "PANDOC_PATH"
    case pdfEngine = "PDF_ENGINE"
  }

}

extension EnvClient: DependencyKey {
  static let testValue = Self()
  static let liveValue = Self(env: {
    // Convert default values into a dictionary.
    let defaults =
      (try? encoder.encode(EnvVars()))
      .flatMap { try? decoder.decode([String: String].self, from: $0) }
      ?? [:]

    // Merge the default values with values found in process environment.
    let assigned = defaults.merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })

    return (try? JSONSerialization.data(withJSONObject: assigned))
      .flatMap { try? decoder.decode(EnvVars.self, from: $0) }
      ?? .init()
  })
}

private let encoder: JSONEncoder = {
  JSONEncoder()
}()

private let decoder: JSONDecoder = {
  JSONDecoder()
}()
