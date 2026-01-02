import Elementary

public struct MainPage<Inner: HTML>: SendableHTMLDocument where Inner: Sendable {
  public var title: String { "Manual-D" }
  public var lang: String { "en" }
  let inner: Inner
  let activeTab: Sidebar.ActiveTab
  let showSidebar: Bool

  init(
    active activeTab: Sidebar.ActiveTab,
    showSidebar: Bool = true,
    _ inner: () -> Inner
  ) {
    self.activeTab = activeTab
    self.showSidebar = showSidebar
    self.inner = inner()
  }

  public var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
    script(.src("https://unpkg.com/htmx.org@2.0.8")) {}
    script(.src("/js/main.js")) {}
    link(.rel(.stylesheet), .href("/css/output.css"))
    link(.rel(.icon), .href("/images/favicon.ico"), .custom(name: "type", value: "image/x-icon"))
  }

  public var body: some HTML {
    // div(.class("bg-white dark:bg-gray-800 dark:text-white")) {
    div {
      div(.class("flex flex-row")) {
        if showSidebar {
          Sidebar(active: activeTab)
        }
        main(.class("flex flex-col h-screen w-full px-6 py-10")) {
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
