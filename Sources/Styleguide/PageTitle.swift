import Elementary

public struct PageTitleRow<Content: HTML>: HTML, Sendable where Content: Sendable {

  let inner: Content

  public init(@HTMLBuilder content: () -> Content) {
    self.inner = content()
  }

  public var body: some HTML<HTMLTag.div> {
    div(
      .class(
        """
        flex justify-between bg-secondary border-2 border-primary rounded-sm shadow-sm 
        p-6 w-full
        """
      )
    ) {
      inner
    }
  }
}

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
