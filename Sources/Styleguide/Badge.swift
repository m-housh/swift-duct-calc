import Elementary
import Tagged

public struct Badge<Inner: HTML>: HTML, Sendable where Inner: Sendable {

  let inner: Inner

  public init(
    @HTMLBuilder inner: () -> Inner
  ) {
    self.inner = inner()
  }

  public var body: some HTML<HTMLTag.div> {
    div(.class("badge badge-lg badge-outline")) {
      inner
    }
  }
}

extension Badge where Inner == Number {
  public init(number: Int) {
    self.inner = Number(number)
  }

  public init(number: Double, digits: Int = 2) {
    self.inner = Number(number, digits: digits)
  }

}
