import DatabaseClient
import Foundation
import ManualDCore

/// Common persistence limits for both path editors.
enum PathValidation {
  static let maximumRows = 1000
  static let maximumQuantity = 1_000_000

  static func name(_ name: String, straightLengths: [Int], rowCount: Int) throws -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 200, rowCount <= maximumRows,
      straightLengths.count <= 100, straightLengths.allSatisfy({ $0 > 0 })
    else {
      throw ValidationError(
        "Enter a path name and positive straight lengths, with at most 100 lengths and 1,000 fittings."
      )
    }
    return trimmed
  }

  static func validate(_ groups: [EquivalentLength.FittingGroup]) throws {
    guard
      groups.allSatisfy({
        $0.quantity > 0 && $0.quantity <= maximumQuantity && $0.value.isFinite && $0.value >= 0
      }), groups.totalEquivalentLength.isFinite
    else {
      throw ValidationError(
        "Use quantities between 1 and 1,000,000 and finite fitting lengths and totals.")
    }
  }
}
