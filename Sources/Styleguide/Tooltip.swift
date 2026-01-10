import Elementary

public struct Tooltip<Inner: HTML & Sendable>: HTML, Sendable {

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

public enum TooltipPosition: String, CaseIterable, Sendable {

  public static let `default` = Self.left

  case bottom
  case left
  case right
  case top
}
