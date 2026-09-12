import Elementary
import ManualDCore
import Styleguide

struct HomePage: SendableHTMLDocument {
  var isLoggedIn = false
  var title: String { "DuctCalc · Residential duct design" }
  var lang: String { "en" }
  private let description = "Residential duct design based on the Manual-D workflow. Import room loads, trace duct paths, calculate friction rate, and size ducts in your browser."

  var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
    meta(.name("color-scheme"), .content("light dark"))
    meta(.name("description"), .content(description))
    meta(.custom(name: "property", value: "og:site_name"), .content("DuctCalc"))
    meta(.custom(name: "property", value: "og:title"), .content(title))
    meta(.custom(name: "property", value: "og:description"), .content(description))
    meta(.custom(name: "property", value: "og:type"), .content("website"))
    meta(.custom(name: "property", value: "og:image"), .content("/images/mand_logo.png"))
    meta(.name("twitter:card"), .content("summary_large_image"))
    meta(.name("twitter:title"), .content(title))
    meta(.name("twitter:description"), .content(description))
    meta(.name("twitter:image"), .content("/images/mand_logo.png"))
    link(.rel(.icon), .href("/images/favicon.ico"))
    link(.rel(.icon), .href("/images/favicon-32x32.png"), .custom(name: "sizes", value: "32x32"))
    link(.rel(.init(rawValue: "apple-touch-icon")), .href("/images/apple-touch-icon.png"))
    link(.rel(.init(rawValue: "manifest")), .href("/site.webmanifest"))
    link(.rel(.stylesheet), .href("/css/home.css?v=1"))
    link(.rel(.stylesheet), .href("/css/ductcalc-wordmark.css?v=1"))
    script(.src("/js/home.js?v=1"), .custom(name: "defer", value: "")) {}
  }

  var body: some HTML {
    div(.class("landing workspace")) {
      a(.class("landing-skip"), .href("#landing-content")) { "Skip to content" }
      header(.class("landing-header wrap")) {
        a(.class("landing-brand"), .href(route: .home)) {
          DuctCalcWordmark()
          span(.class("brand-beta")) { "BETA" }
        }
        nav(.custom(name: "aria-label", value: "Main navigation")) {
          a(.href(route: .fittingReference(.init()))) { "Fitting reference" }
          a(.href(route: isLoggedIn ? .project(.index) : .login(.index()))) {
            isLoggedIn ? "Projects ↗" : "Log in ↗"
          }
        }
      }
      main(.id("landing-content"), .tabindex(-1), .class("wrap workspace-main")) {
        section(.class("workspace-intro")) {
          div {
            h1 {
              "Your next duct design,"
              br()
              em { "all in one place." }
            }
          }
          div(.class("workspace-pitch")) {
            a(.class("landing-cta"), .href(route: isLoggedIn ? .project(.index) : .signup(.index))) {
              isLoggedIn ? "Open your projects" : "Start a project"
              span(.custom(name: "aria-hidden", value: "true")) { "↗" }
            }
            a(.class("text-link"), .href(route: .ductulator(.index))) {
              "Just need a duct size? Try the ductulator →"
            }
          }
        }
        HomeProjectPreview()
        p(.class("workspace-summary")) {
          "Bring your room loads. Work through the paths, pressure losses, and duct sizes. Keep the whole job together."
        }
        section(.class("workspace-bottom")) {
          h2 { "The speed sheet grew up." }
          p {
            "The familiar Manual-D workflow, with CoolCalc imports, reusable path templates, and a PDF to take to the job."
          }
          a(.class("text-link"), .href("https://github.com/m-housh/swift-duct-calc")) {
            "See how it's built ↗"
          }
        }
      }
      footer(.class("landing-footer wrap")) {
        a(.href("https://github.com/m-housh/swift-duct-calc")) { "Source available ↗" }
        a(.href("mailto:support@ductcalc.pro")) { "Contact Michael" }
        a(.href(route: .privacyPolicy)) { "Privacy" }
        p {
          "Manual-D™ is a trademark of ACCA. DuctCalc is not affiliated with or endorsed by ACCA."
        }
      }
    }
  }
}
