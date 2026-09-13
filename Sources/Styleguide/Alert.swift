import Elementary

public struct Alert<Content: HTML>: HTML {

  let inner: Content

  public init(@HTMLBuilder content: () -> Content) {
    self.inner = content()
  }

  public var body: some HTML<HTMLTag.div> {
    div(.class("flex items-start gap-3 py-2 leading-relaxed")) {
      span(.class("mt-0.5 shrink-0 text-warning")) { SVG(.triangleAlert) }
      div(.class("min-w-0")) { inner }
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
