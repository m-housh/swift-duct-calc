import Foundation

public struct EffectiveLengthGroup: Codable, Equatable {
  public let group: Int
  public let letter: String
  public let effectiveLength: Int
  public let category: Category
  public var label: String { "\(group)\(letter.uppercased())" }

  public init(
    group: Int,
    letter: String,
    effectiveLength: Int,
    category: Category
  ) {
    self.group = group
    self.letter = letter
    self.effectiveLength = effectiveLength
    self.category = category
  }
}

extension EffectiveLengthGroup {

  public enum Category: String, Codable, Equatable {
    case supply
    case `return`
  }

}
