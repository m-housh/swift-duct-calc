import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

public struct MainPage<Inner: HTML>: SendableHTMLDocument where Inner: Sendable {

  public var title: String { "Duct Calc" }
  public var lang: String { "en" }

  let inner: Inner
  let theme: Theme?
  let displayFooter: Bool

  init(
    displayFooter: Bool = true,
    theme: Theme? = nil,
    _ inner: () -> Inner
  ) {
    self.displayFooter = displayFooter
    self.theme = theme
    self.inner = inner()
  }

  private var summary: String {
    """
    Duct sizing based on ACCA, Manual-D.
    """
  }

  private var keywords: String {
    """
    duct, hvac, duct-design, duct design, manual-d, manual d, design
    """
  }

  public var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
    meta(.content("ductcalc.com"), .name("og:site_name"))
    meta(.content("Duct Calc"), .name("og:title"))
    meta(.content(summary), .name("description"))
    meta(.content(summary), .name("og:description"))
    meta(.content("/images/mand_logo.png"), .name("og:image"))
    meta(.content("/images/mand_logo.png"), .name("twitter:image"))
    meta(.content("Duct Calc"), .name("twitter:image:alt"))
    meta(.content("summary_large_image"), .name("twitter:card"))
    meta(.content("1536"), .name("og:image:width"))
    meta(.content("1024"), .name("og:image:height"))
    meta(.content(keywords), .name(.keywords))
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
    div(.class("flex flex-col min-h-screen min-w-full justify-between")) {
      main(.class("flex flex-col min-h-screen min-w-full grow mb-auto")) {
        inner
      }

      div(.class("bottom-0 left-0 bg-error")) {
        if displayFooter {
          footer(
            .class(
              """
              footer sm:footer-horizontal footer-center
              bg-base-300 text-base-content p-4
              """
            )
          ) {
            aside {
              p {
                "Copyright © \(Date().description.prefix(4)) - All rights reserved by Michael Housh"
              }
            }
          }
        }
      }
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
