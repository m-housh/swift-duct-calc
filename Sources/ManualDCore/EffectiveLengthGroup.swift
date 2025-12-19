import Foundation

// TODO: Add other description / label for items that have same group & letter, but
//       different effective length.
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

public let effectiveLengthsLookup: [String: EffectiveLengthGroup] {
  [
    "1a": .init(group: 1, letter: "a", effectiveLength: 35, category: .supply),
    "1b": .init(group: 1, letter: "b", effectiveLength: 10, category: .supply),
    "1c": .init(group: 1, letter: "c", effectiveLength: 35, category: .supply),
    "1d": .init(group: 1, letter: "d", effectiveLength: 10, category: .supply),
    "1e": .init(group: 1, letter: "e", effectiveLength: 10, category: .supply),
    "1f-0.5": .init(group: 1, letter: "f", effectiveLength: 120, category: .supply),
    "1f-1": .init(group: 1, letter: "f", effectiveLength: 85, category: .supply),
    "1g-0.5": .init(group: 1, letter: "g", effectiveLength: 35, category: .supply),
    "1g-1": .init(group: 1, letter: "g", effectiveLength: 25, category: .supply),
    "1h-0.5": .init(group: 1, letter: "h", effectiveLength: 120, category: .supply),
    "1h-1": .init(group: 1, letter: "h", effectiveLength: 85, category: .supply),
    "1i": .init(group: 1, letter: "i", effectiveLength: 20, category: .supply),
    "1k": .init(group: 1, letter: "k", effectiveLength: 85, category: .supply),
    "1l-0.25": .init(group: 1, letter: "l", effectiveLength: 40, category: .supply),
    "1l-0.5": .init(group: 1, letter: "l", effectiveLength: 20, category: .supply),
    "1l-1": .init(group: 1, letter: "l", effectiveLength: 10, category: .supply),
    "1m-0.05-1": .init(group: 1, letter: "m", effectiveLength: 30, category: .supply),
    "1m-0.05-2": .init(group: 1, letter: "m", effectiveLength: 20, category: .supply),
    "1m-0.25-1": .init(group: 1, letter: "m", effectiveLength: 20, category: .supply),
    "1m-0.25-2": .init(group: 1, letter: "m", effectiveLength: 10, category: .supply),
    "1m-0.5-1": .init(group: 1, letter: "m", effectiveLength: 10, category: .supply),
    "1m-0.5-2": .init(group: 1, letter: "m", effectiveLength: 10, category: .supply),
    "1n": .init(group: 1, letter: "n", effectiveLength: 15, category: .supply),
    "1o-0.5": .init(group: 1, letter: "o", effectiveLength: 120, category: .supply),
    "1o-1": .init(group: 1, letter: "o", effectiveLength: 85, category: .supply),
    "1p": .init(group: 1, letter: "p", effectiveLength: 20, category: .supply),
    "1q": .init(group: 1, letter: "q", effectiveLength: 50, category: .supply),
    "1r": .init(group: 1, letter: "r", effectiveLength: 120, category: .supply),
    "1s-0": .init(group: 1, letter: "s", effectiveLength: 60, category: .supply),
    "1s-1": .init(group: 1, letter: "s", effectiveLength: 40, category: .supply),
    "1s-2": .init(group: 1, letter: "s", effectiveLength: 30, category: .supply),
    "1t": .init(group: 1, letter: "t", effectiveLength: 60, category: .supply),
    // Group 2
    "2a-0": .init(group: 2, letter: "a", effectiveLength: 35, category: .supply),
    "2a-1": .init(group: 2, letter: "a", effectiveLength: 45, category: .supply),
    "2a-2": .init(group: 2, letter: "a", effectiveLength: 55, category: .supply),
    "2a-3": .init(group: 2, letter: "a", effectiveLength: 65, category: .supply),
    "2a-4": .init(group: 2, letter: "a", effectiveLength: 70, category: .supply),
    "2a-5": .init(group: 2, letter: "a", effectiveLength: 80, category: .supply),

    "2b-0": .init(group: 2, letter: "b", effectiveLength: 20, category: .supply),
    "2b-1": .init(group: 2, letter: "b", effectiveLength: 30, category: .supply),
    "2b-2": .init(group: 2, letter: "b", effectiveLength: 35, category: .supply),
    "2b-3": .init(group: 2, letter: "b", effectiveLength: 40, category: .supply),
    "2b-4": .init(group: 2, letter: "b", effectiveLength: 45, category: .supply),
    "2b-5": .init(group: 2, letter: "b", effectiveLength: 50, category: .supply),

    "2c-0": .init(group: 2, letter: "c", effectiveLength: 65, category: .supply),
    "2c-1": .init(group: 2, letter: "c", effectiveLength: 65, category: .supply),
    "2c-2": .init(group: 2, letter: "c", effectiveLength: 65, category: .supply),
    "2c-3": .init(group: 2, letter: "c", effectiveLength: 65, category: .supply),
    "2c-4": .init(group: 2, letter: "c", effectiveLength: 70, category: .supply),
    "2c-5": .init(group: 2, letter: "c", effectiveLength: 80, category: .supply),

    "2d-0": .init(group: 2, letter: "d", effectiveLength: 40, category: .supply),
    "2d-1": .init(group: 2, letter: "d", effectiveLength: 50, category: .supply),
    "2d-2": .init(group: 2, letter: "d", effectiveLength: 60, category: .supply),
    "2d-3": .init(group: 2, letter: "d", effectiveLength: 65, category: .supply),
    "2d-4": .init(group: 2, letter: "d", effectiveLength: 75, category: .supply),
    "2d-5": .init(group: 2, letter: "d", effectiveLength: 85, category: .supply),

    "2e-0": .init(group: 2, letter: "e", effectiveLength: 25, category: .supply),
    "2e-1": .init(group: 2, letter: "e", effectiveLength: 30, category: .supply),
    "2e-2": .init(group: 2, letter: "e", effectiveLength: 35, category: .supply),
    "2e-3": .init(group: 2, letter: "e", effectiveLength: 40, category: .supply),
    "2e-4": .init(group: 2, letter: "e", effectiveLength: 45, category: .supply),
    "2e-5": .init(group: 2, letter: "e", effectiveLength: 50, category: .supply),

    "2f-0": .init(group: 2, letter: "f", effectiveLength: 20, category: .supply),
    "2f-1": .init(group: 2, letter: "f", effectiveLength: 20, category: .supply),
    "2f-2": .init(group: 2, letter: "f", effectiveLength: 20, category: .supply),
    "2f-3": .init(group: 2, letter: "f", effectiveLength: 20, category: .supply),
    "2f-4": .init(group: 2, letter: "f", effectiveLength: 25, category: .supply),
    "2f-5": .init(group: 2, letter: "f", effectiveLength: 25, category: .supply),

    "2g-0": .init(group: 2, letter: "g", effectiveLength: 65, category: .supply),
    "2g-1": .init(group: 2, letter: "g", effectiveLength: 65, category: .supply),
    "2g-2": .init(group: 2, letter: "g", effectiveLength: 65, category: .supply),
    "2g-3": .init(group: 2, letter: "g", effectiveLength: 70, category: .supply),
    "2g-4": .init(group: 2, letter: "g", effectiveLength: 80, category: .supply),
    "2g-5": .init(group: 2, letter: "g", effectiveLength: 90, category: .supply),

    "2h-0": .init(group: 2, letter: "h", effectiveLength: 70, category: .supply),
    "2h-1": .init(group: 2, letter: "h", effectiveLength: 70, category: .supply),
    "2h-2": .init(group: 2, letter: "h", effectiveLength: 70, category: .supply),
    "2h-3": .init(group: 2, letter: "h", effectiveLength: 75, category: .supply),
    "2h-4": .init(group: 2, letter: "h", effectiveLength: 85, category: .supply),
    "2h-5": .init(group: 2, letter: "h", effectiveLength: 95, category: .supply),
  ]
}
