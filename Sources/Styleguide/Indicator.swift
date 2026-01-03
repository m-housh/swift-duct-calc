import Elementary

public struct Indicator: HTML, Sendable {

  let size: Size

  public init(size: Size = .lg) {
    self.size = size
  }

  public var body: some HTML<HTMLTag.span> {
    span(.class("loading loading-spinner \(size.class) htmx-indicator")) {}
  }

  public enum Size: String, Equatable, Sendable {
    case xs
    case sm
    case md
    case lg
    case xl

    var `class`: String {
      "loading-\(rawValue)"
    }
  }
}
