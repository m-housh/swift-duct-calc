import Elementary

public struct PageTitle: HTML, Sendable {

  let title: String

  public init(_ title: String) {
    self.title = title
  }

  public init(_ title: () -> String) {
    self.title = title()
  }

  public var body: some HTML<HTMLTag.h1> {
    h1(.class("text-3xl font-bold")) { title }
  }
}
