import Foundation

public enum Theme: String, CaseIterable, Codable, Equatable, Sendable {
  case aqua
  case cupcake
  case cyberpunk
  case dark
  case dracula
  case light
  case night
  case nord
  case retro
  case synthwave

  public static let darkThemes = [
    Self.aqua,
    Self.dark,
    Self.dracula,
    Self.night,
    Self.synthwave,
  ]

  public static let lightThems = [
    Self.cupcake,
    Self.cyberpunk,
    Self.light,
    Self.nord,
    Self.retro,
  ]
}
