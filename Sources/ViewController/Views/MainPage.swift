import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

public struct MainPage<Inner: HTML>: SendableHTMLDocument where Inner: Sendable {

  public var title: String { pageTitle }
  public var lang: String { "en" }

  let inner: Inner
  let theme: Theme?
  let keybindings: Keybindings
  let displayFooter: Bool
  let pageTitle: String
  let stylesheets: [String]
  let scripts: [String]

  init(
    displayFooter: Bool = true,
    theme: Theme? = nil,
    keybindings: Keybindings = .init(),
    title: String = "Duct Calc",
    stylesheets: [String] = [],
    scripts: [String] = [],
    _ inner: () -> Inner
  ) {
    self.displayFooter = displayFooter
    self.theme = theme
    self.keybindings = keybindings
    self.pageTitle = title
    self.stylesheets = stylesheets
    self.scripts = scripts
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
    script(.src("/js/request-errors.js?v=1")) {}
    script(.src("/js/main.js?v=keybindings-11")) {}
    script(.src("/js/shortcut-hints.js?v=6")) {}
    link(.rel(.stylesheet), .href("/css/shortcut-hints.css?v=1"))
    script(.src("/js/file-import.js?v=1"), .defer) {}
    script(.src("/js/filters.js?v=1"), .defer) {}
    link(.rel(.stylesheet), .href("/css/filters.css?v=1"))
    script(.src("/js/project-import.js?v=1"), .defer) {}
    link(.rel(.stylesheet), .href("/css/output.css?v=project-import-1"))
    link(.rel(.stylesheet), .href("/css/htmx.css"))
    link(.rel(.stylesheet), .href("/css/accessibility.css?v=errors-1"))
    link(.rel(.stylesheet), .href("/css/project-workspace.css?v=rooms-table-1"))
    AppIcons()
    link(.rel(.stylesheet), .href("/css/ductcalc-wordmark.css?v=2"))
    link(.rel(.stylesheet), .href("/css/navbar.css?v=3"))
    for stylesheet in stylesheets {
      link(.rel(.stylesheet), .href(stylesheet))
    }
    for source in scripts {
      script(.src(source), .init(name: "defer", value: "")) {}
    }
  }

  public var body: some HTML {
    div(.class("flex flex-col min-h-screen min-w-full justify-between")) {
      a(.class("skip-link"), .href("#main-content")) { "Skip to content" }
      main(
        .id("main-content"), .tabindex(-1),
        .class("flex flex-col min-h-screen min-w-full grow mb-auto")
      ) {
        inner.environment(ShortcutViewValue.$bindings, keybindings)
      }

      div(
        .id("app-status"), .class("sr-only"), .role("status"),
        .init(name: "aria-atomic", value: "true")
      ) {}
      div(.id("app-error"), .class("request-error"), .role("alert")) {}
      div {
        if displayFooter {
          footer(
            .class(
              """
              footer footer-horizontal footer-center
              bg-base-300 text-base-content p-4
              """
            )
          ) {
            div(
              .class("grid-flow-row items-center")
            ) {

              div(.class("flex mx-auto")) {
                a(
                  .class("btn btn-ghost"),
                  .href("mailto:support@ductcalc.pro")
                ) {
                  SVG(.email)
                  span { "support@ductcalc.pro" }
                }
              }

              a(
                .class("btn btn-ghost mx-auto"),
                .href("https://github.com/m-housh/swift-duct-calc/src/branch/main/LICENSE"),
                .target(.blank)
              ) {
                span { "Source available via PolyForm Perimeter 1.0.1" }
              }

              p(.class("")) {
                "Copyright © \(Date().description.prefix(4)) - All rights reserved by Michael Housh"
              }
            }
          }
        }
      }
    }
    .attributes(
      .data("keybindings", value: keybindingsJSON(keybindings.resolved))
    )
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
