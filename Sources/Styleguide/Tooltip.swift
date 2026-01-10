import Elementary

public struct Tooltip<Inner: HTML & Sendable>: HTML, Sendable {

  let tooltip: String
  let inner: Inner

  public init(
    _ tooltip: String,
    @HTMLBuilder inner: () -> Inner
  ) {
    self.tooltip = tooltip
    self.inner = inner()
  }

  public var body: some HTML<HTMLTag.div> {
    div(
      .class("tooltip"),
      .data("tip", value: tooltip)
    ) {
      inner
    }
  }
}
