import Elementary

public struct Label: HTML, Sendable {

  let title: String

  public init(_ title: String) {
    self.title = title
  }

  public init(_ title: @escaping () -> String) {
    self.title = title()
  }

  public var body: some HTML<HTMLTag.span> {
    span(.class("text-xl text-secondary font-bold")) {
      title
    }
  }
}
