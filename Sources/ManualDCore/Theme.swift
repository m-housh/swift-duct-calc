import Foundation

public enum Theme: String, CaseIterable, Codable, Equatable, Sendable {
  case aqua
  case cupcake
  case cyberpunk
  case dark
  case `default`
  case dracula
  case light
  case night
  case nord
  case retro
  case synthwave

  public static let darkThemes = [
    Self.aqua,
    Self.cyberpunk,
    Self.dark,
    Self.dracula,
    Self.night,
    Self.synthwave,
  ]

  public static let lightThemes = [
    Self.cupcake,
    Self.light,
    Self.nord,
    Self.retro,
  ]
}
