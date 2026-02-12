import Dependencies
import DependenciesMacros
import FileClient
import Foundation

extension DependencyValues {

  /// Holds values defined in the process environment that are needed.
  ///
  /// These are generally loaded from a `.env` file, but also have default values,
  /// if not found.
  public var environment: EnvVars {
    get { self[EnvVars.self] }
    set { self[EnvVars.self] = newValue }
  }
}

/// Holds values defined in the process environment that are needed.
///
/// These are generally loaded from a `.env` file, but also have default values,
/// if not found.
public struct EnvVars: Codable, Equatable, Sendable {

  /// The path to the pandoc executable on the system, used to generate pdf's.
  public let pandocPath: String

  /// The pdf engine to use with pandoc when creating pdf's.
  public let pdfEngine: String

  /// The postgres hostname, used for production database connection.
  public let postgresHostname: String?

  /// The postgres username, used for production database connection.
  public let postgresUsername: String?

  /// The postgres password, used for production database connection.
  public let postgresPassword: String?

  /// The postgres database, used for production database connection.
  public let postgresDatabase: String?

  /// The path to the sqlite database, used for development database connection.
  public let sqlitePath: String?

  public init(
    pandocPath: String = "/usr/bin/pandoc",
    pdfEngine: String = "weasyprint",
    postgresHostname: String? = "localhost",
    postgresUsername: String? = "vapor",
    postgresPassword: String? = "super-secret",
    postgresDatabase: String? = "vapor",
    sqlitePath: String? = "db.sqlite"
  ) {
    self.pandocPath = pandocPath
    self.pdfEngine = pdfEngine
    self.postgresHostname = postgresHostname
    self.postgresUsername = postgresUsername
    self.postgresPassword = postgresPassword
    self.postgresDatabase = postgresDatabase
    self.sqlitePath = sqlitePath
  }

  enum CodingKeys: String, CodingKey {
    case pandocPath = "PANDOC_PATH"
    case pdfEngine = "PDF_ENGINE"
    case postgresHostname = "POSTGRES_HOSTNAME"
    case postgresUsername = "POSTGRES_USER"
    case postgresPassword = "POSTGRES_PASSWORD"
    case postgresDatabase = "POSTGRES_DB"
    case sqlitePath = "SQLITE_PATH"
  }

  public static func live(
    _ env: [String: String] = ProcessInfo.processInfo.environment
  ) async throws -> Self {

    // Convert default values into a dictionary.
    let defaults =
      (try? encoder.encode(EnvVars()))
      .flatMap { try? decoder.decode([String: String].self, from: $0) }
      ?? [:]

    // Merge the default values with values found in process environment.
    var assigned = defaults.merging(env, uniquingKeysWith: { $1 })

    // Merge with file(s), used with docker secrets.
    try await mergeWithFileData(&assigned)

    return (try? JSONSerialization.data(withJSONObject: assigned))
      .flatMap { try? decoder.decode(EnvVars.self, from: $0) }
      ?? .init()
  }

}

private func mergeWithFileData(_ dict: inout [String: String]) async throws {

  // Helper that reads contents of file, and set's the value into the
  // dictionary.
  func mergeFromFile(
    _ key: EnvVars.CodingKeys
  ) async throws {
    @Dependency(\.fileClient) var fileClient
    if let filePath = dict["\(key.stringValue)_FILE"] {
      let data = try await fileClient.readFile(filePath)
      if let value = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines
      ) {
        dict[key.stringValue] = value
      }
    }
  }

  try await mergeFromFile(.postgresPassword)
  try await mergeFromFile(.postgresDatabase)
  try await mergeFromFile(.postgresUsername)
}

extension EnvVars: TestDependencyKey {
  public static let testValue = Self()
}

private let encoder: JSONEncoder = {
  JSONEncoder()
}()

private let decoder: JSONDecoder = {
  JSONDecoder()
}()
