import Elementary

public struct Row<T: HTML>: HTML, Sendable where T: Sendable {

  let inner: T

  public init(
    @HTMLBuilder _ body: () -> T
  ) {
    self.inner = body()
  }

  public var body: some HTML<HTMLTag.div> {
    div(.class("flex justify-between")) {
      inner
    }
  }
}
