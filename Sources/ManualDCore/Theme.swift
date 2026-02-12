import Foundation

/// Represents supported color themes for the website.
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

  /// Represents dark color themes.
  public static let darkThemes = [
    Self.aqua,
    Self.cyberpunk,
    Self.dark,
    Self.dracula,
    Self.night,
    Self.synthwave,
  ]

  /// Represents light color themes.
  public static let lightThemes = [
    Self.cupcake,
    Self.light,
    Self.nord,
    Self.retro,
  ]
}
