import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

public struct MainPage<Inner: HTML>: SendableHTMLDocument where Inner: Sendable {

  public var title: String { "Duct Calc" }
  public var lang: String { "en" }

  let inner: Inner
  let theme: Theme?

  init(
    theme: Theme? = nil,
    _ inner: () -> Inner
  ) {
    self.theme = theme
    self.inner = inner()
  }

  public var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
    script(.src("https://unpkg.com/htmx.org@2.0.8")) {}
    script(.src("/js/main.js")) {}
    link(.rel(.stylesheet), .href("/css/output.css"))
    link(
      .rel(.icon),
      .href("/images/favicon.ico"),
      .init(name: "type", value: "image/x-icon")
    )
    link(
      .rel(.icon),
      .href("/images/favicon-32x32.png"),
      .init(name: "type", value: "image/png")
    )
    link(
      .rel(.icon),
      .href("/images/favicon-16x16.png"),
      .init(name: "type", value: "image/png")
    )
    link(
      .rel(.init(rawValue: "apple-touch-icon")),
      .init(name: "sizes", value: "180x180"),
      .href("/images/apple-touch-icon.png")
    )
    link(.rel(.init(rawValue: "manifest")), .href("/site.webmanifest"))
    script(
      .src("https://unpkg.com/htmx-remove@latest"),
      .crossorigin(.anonymous),
      .integrity("sha384-NwB2Xh66PNEYfVki0ao13UAFmdNtMIdBKZ8sNGRT6hKfCPaINuZ4ScxS6vVAycPT")
    ) {}
  }

  public var body: some HTML {
    div(.class("h-screen w-full")) {
      inner
    }
    .attributes(.data("theme", value: theme?.rawValue ?? "default"), when: theme != nil)
  }
}

struct LoggedIn: HTML, Sendable {
  let next: String

  init(next: String? = nil) {
    self.next = next ?? SiteRoute.View.router.path(for: .project(.index))
  }

  var body: some HTML {
    div(
      .hx.get(next),
      .hx.pushURL(true),
      .hx.target("body"),
      .hx.trigger(.event(.revealed)),
      .hx.indicator()
    ) {
      Indicator()
    }
  }

}

public protocol SendableHTMLDocument: HTMLDocument, Sendable {}
