import Elementary

public struct MainPage<Inner: HTML>: SendableHTMLDocument where Inner: Sendable {
  public var title: String { "Manual-D" }
  public var lang: String { "en" }
  let inner: Inner

  init(_ inner: () -> Inner) {
    self.inner = inner()
  }

  public var head: some HTML {
    meta(.charset(.utf8))
    script(.src("https://unpkg.com/htmx.org@2.0.8")) {}
    script(.src("/js/main.js")) {}
    link(.rel(.stylesheet), .href("/css/main.css"))
    link(.rel(.icon), .href("/images/favicon.ico"), .custom(name: "type", value: "image/x-icon"))
  }

  public var body: some HTML {
    inner
  }
}

public protocol SendableHTMLDocument: HTMLDocument, Sendable {}
