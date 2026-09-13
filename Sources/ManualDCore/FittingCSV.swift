import Foundation

/// Transcribed per-fitting lengths, before catalog identity and path applicability are checked.
public struct FittingCSV: Sendable {
  public static let byteLimit = 65_536
  public static let rowLimit = 500

  public struct Row: Equatable, Sendable {
    public let line: Int
    public let code: String
    public let feet: Double
    public let quantity: Int

    public init(line: Int, code: String, feet: Double, quantity: Int) {
      self.line = line
      self.code = code
      self.feet = feet
      self.quantity = quantity
    }
  }

  public struct Issue: Equatable, Sendable {
    public let line: Int
    public let field: String
    public let message: String

    public init(line: Int, field: String, message: String) {
      self.line = line
      self.field = field
      self.message = message
    }
  }

  public var rows: [Row]
  public var issues: [Issue]

  public init(rows: [Row] = [], issues: [Issue] = []) {
    self.rows = rows
    self.issues = issues
  }
}
