import Elementary

public struct Alert<Content: HTML>: HTML {

  let inner: Content

  public init(@HTMLBuilder content: () -> Content) {
    self.inner = content()
  }

  public var body: some HTML<HTMLTag.div> {
    div(.class("flex space-x-2")) {
      SVG(.triangleAlert)
      inner
    }
  }
}

extension Alert: Sendable where Content: Sendable {}

extension Alert where Content == p<HTMLText> {

  public init(_ description: String) {
    self.init {
      p { description }
    }
  }
}
