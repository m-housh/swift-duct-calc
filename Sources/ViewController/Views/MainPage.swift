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
    meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
    script(.src("https://unpkg.com/htmx.org@2.0.8")) {}
    script(.src("https://cdn.tailwindcss.com")) {}
    script(.src("/js/main.js")) {}
    link(.rel(.stylesheet), .href("/css/main.css"))
    link(.rel(.icon), .href("/images/favicon.ico"), .custom(name: "type", value: "image/x-icon"))
  }

  public var body: some HTML {
    div(.class("bg-white dark:bg-gray-800 dark:text-white")) {
      div(.class("flex flex-row")) {
        Sidebar()
        main(.class("flex flex-col h-screen w-full")) {
          inner
        }
      }
    }
    script(.src("https://unpkg.com/lucide@latest")) {}
    script {
      "lucide.createIcons();"
    }
  }
}

public protocol SendableHTMLDocument: HTMLDocument, Sendable {}
