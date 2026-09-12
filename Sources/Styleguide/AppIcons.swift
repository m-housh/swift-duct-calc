import Elementary

public struct AppIcons: HTML, Sendable {
  public init() {}

  public var body: some HTML {
    link(.rel(.icon), .href("/images/favicon.ico?v=ductcalc-2"), .custom(name: "sizes", value: "16x16 32x32 48x48"))
    link(.rel(.icon), .href("/images/favicon-32x32.png?v=ductcalc-2"), .custom(name: "type", value: "image/png"), .custom(name: "sizes", value: "32x32"))
    link(.rel(.icon), .href("/images/brand/favicon.svg"), .custom(name: "type", value: "image/svg+xml"), .custom(name: "sizes", value: "any"))
    link(.rel(.init(rawValue: "apple-touch-icon")), .href("/images/apple-touch-icon.png?v=ductcalc-2"), .custom(name: "sizes", value: "180x180"))
    link(.rel(.init(rawValue: "manifest")), .href("/site.webmanifest?v=ductcalc-2"))
  }
}
