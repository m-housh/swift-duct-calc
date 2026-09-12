import Elementary

/// The airflow icon supplies the D; its middle band shares the C's accent color.
public struct DuctCalcWordmark: HTML, Sendable {
  private let appTheme: Bool

  public init(appTheme: Bool = false) {
    self.appTheme = appTheme
  }

  public var body: some HTML {
    span(
      .class("dc-wordmark"), .role("img"),
      .custom(name: "aria-label", value: "DuctCalc, residential duct design")
    ) {
      span(.class("dc-wordmark-name"), .custom(name: "aria-hidden", value: "true")) {
        if appTheme {
          span(.class("dc-wordmark-icon")) {
            img(.class("dc-mark-light"), .src("/images/brand/ductcalc-mark-light.webp"), .alt(""), .width(50), .height(50))
            img(.class("dc-mark-dark"), .src("/images/brand/ductcalc-mark-dark.webp"), .alt(""), .width(50), .height(50))
          }
        } else {
          picture(.class("dc-wordmark-icon")) {
            source(
              .custom(name: "media", value: "(prefers-color-scheme: dark)"),
              .custom(name: "srcset", value: "/images/brand/ductcalc-mark-dark.webp"))
            img(.src("/images/brand/ductcalc-mark-light.webp"), .alt(""), .width(50), .height(50))
          }
        }
        span { "uct" }
        span(.class("dc-wordmark-c")) { "C" }
        span { "alc" }
      }
      span(.class("dc-wordmark-description"), .custom(name: "aria-hidden", value: "true")) {
        "Residential duct design"
      }
    }
  }
}
