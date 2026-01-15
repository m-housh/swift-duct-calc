import Elementary

extension HTML {

  public func tooltip(
    _ tip: String,
    position: TooltipPosition = .default
  ) -> Tooltip<Self> {
    Tooltip(tip, position: position) {
      self
    }
  }
}

public struct Tooltip<Inner: HTML>: HTML {

  let tooltip: String
  let position: TooltipPosition
  let inner: Inner

  public init(
    _ tooltip: String,
    position: TooltipPosition = .default,
    @HTMLBuilder inner: () -> Inner
  ) {
    self.tooltip = tooltip
    self.position = position
    self.inner = inner()
  }

  public var body: some HTML<HTMLTag.div> {
    div(
      .class("tooltip tooltip-\(position.rawValue)"),
      .data("tip", value: tooltip)
    ) {
      inner
    }
  }
}

extension Tooltip: Sendable where Inner: Sendable {}

public enum TooltipPosition: String, CaseIterable, Sendable {

  public static let `default` = Self.left

  case bottom
  case left
  case right
  case top
}
