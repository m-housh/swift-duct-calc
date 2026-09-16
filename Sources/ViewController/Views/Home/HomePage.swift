import Elementary
import ManualDCore
import Styleguide

struct HomePage: SendableHTMLDocument {
  var isLoggedIn = false
  var title: String { "Residential HVAC Duct Design Software | DuctCalc" }
  var lang: String { "en" }
  private let description =
    "Residential HVAC duct design based on the Manual-D workflow. Import CoolCalc room loads, calculate friction rate, size ducts, and export a PDF for the job."

  var head: some HTML {
    meta(.charset(.utf8))
    meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
    meta(.name("color-scheme"), .content("light dark"))
    meta(.name("description"), .content(description))
    link(.rel("canonical"), .href("https://ductcalc.pro/"))
    SocialPreview(title: title, description: description, url: "https://ductcalc.pro/")
    AppIcons()
    link(.rel(.stylesheet), .href("/css/home.css?v=3"))
    link(.rel(.stylesheet), .href("/css/ductcalc-wordmark.css?v=2"))
    script(.src("/js/home.js?v=2"), .custom(name: "defer", value: "")) {}
  }

  var body: some HTML {
    div(.class("landing")) {
      a(.class("skip-link"), .href("#main-content")) { "Skip to content" }
      header(.class("site-header wrap")) {
        a(.class("brand"), .href(route: .home)) {
          DuctCalcWordmark()
        }
        nav(.custom(name: "aria-label", value: "Main navigation")) {
          a(.href("#chapters")) { "The workflow" }
          a(.href("#quick-tools")) { "Quick tools" }
          a(.href(route: isLoggedIn ? .project(.index) : .login(.index()))) {
            isLoggedIn ? "Projects ↗" : "Log in ↗"
          }
        }
      }
      main(.id("main-content"), .tabindex(-1)) {
        section(.class("hero wrap")) {
          div(.class("hero-copy")) {
            p(.class("eyebrow")) { "RESIDENTIAL DUCT DESIGN, RECONSIDERED" }
            h1 {
              span { "The speed sheet" }
              em { "grew up." }
            }
            p(.class("hero-deck")) {
              "All the calculations. A lot less repetition."
            }
            p(.class("hero-description")) {
              "Your familiar Manual-D workflow, rebuilt for the browser. From CoolCalc room loads to duct sizes and a PDF for the job."
            }
            div(.class("hero-actions")) {
              projectLink
              a(.class("quiet-link"), .href("#chapters")) { "Take a closer look ↓" }
            }
          }
          div(.class("hero-art")) {
            HomeScreen(name: "sizes", hero: true)
            div(.class("hero-note")) {
              span(.class("status-dot"), .custom(name: "aria-hidden", value: "true")) {}
              "The workflow you know. Room to work."
            }
          }
        }
        quickTools
        section(.class("chapter-intro wrap"), .id("chapters")) {
          p(.class("eyebrow")) { "ONE JOB. EVERY CALCULATION." }
          h2 {
            "A better way through the whole job."
          }
          p { "Bring the loads. Build the paths. Work out the pressure. Size the ducts." }
          nav(.class("chapter-links"), .custom(name: "aria-label", value: "Feature sections")) {
            for feature in HomeFeature.allCases {
              a(.href("#\(feature.rawValue)")) { feature.shortTitle }
            }
          }
        }
        div(.class("feature-chapters")) {
          for feature in HomeFeature.allCases {
            HomeFeatureSection(feature: feature)
          }
        }
        section(.class("closing wrap")) {
          p(.class("eyebrow")) { "BUILT BY AN HVAC CONTRACTOR" }
          h2 { "Years in a spreadsheet.\nNow in your browser." }
          p {
            "DuctCalc grew out of the speed sheet I used on my own jobs. The goal is the same: work through the design, know where the numbers came from, and get on with the installation."
          }
          div(.class("closing-actions")) {
            projectLink
            a(.class("quiet-link"), .href("https://github.com/m-housh/swift-duct-calc")) {
              "Explore the source ↗"
            }
          }
          div(.class("closing-notes")) {
            span { "Source available" }
            span { "Self-hostable" }
            span { "Built around real jobs" }
          }
        }
      }
      footer(.class("site-footer wrap")) {
        DuctCalcWordmark()
        div {
          a(.href("mailto:support@ductcalc.pro")) { "Contact Michael" }
          a(.href(route: .privacyPolicy)) { "Privacy" }
        }
        p {
          "Manual-D™ is a trademark of ACCA. DuctCalc is not affiliated with or endorsed by ACCA."
        }
      }
    }
  }

  private var projectLink: some HTML & Sendable {
    a(.class("primary-link"), .href(route: isLoggedIn ? .project(.index) : .signup(.index))) {
      span { isLoggedIn ? "Open your projects" : "Start a project" }
      span(.custom(name: "aria-hidden", value: "true")) { "↗" }
    }
  }

  private var quickTools: some HTML & Sendable {
    section(.class("quick-tools wrap"), .id("quick-tools")) {
      div(.class("quick-heading")) {
        p(.class("eyebrow")) { "NO ACCOUNT NEEDED" }
        h2 { "Just need a quick answer?" }
      }
      a(.class("quick-tool"), .href(route: .ductulator(.index))) {
        span(.class("tool-symbol"), .custom(name: "aria-hidden", value: "true")) { "Ø" }
        div {
          h3 { "Duct sizing calculator" }
          p { "Airflow + friction rate → duct size" }
        }
        span(.class("tool-arrow"), .custom(name: "aria-hidden", value: "true")) { "↗" }
      }
      a(.class("quick-tool"), .href(route: .fittingReference(.init()))) {
        span(.class("tool-symbol fitting-symbol"), .custom(name: "aria-hidden", value: "true")) {
          "↳"
        }
        div {
          h3 { "Fitting reference" }
          p { "Drawings, equivalent lengths, conditions" }
        }
        span(.class("tool-arrow"), .custom(name: "aria-hidden", value: "true")) { "↗" }
      }
    }
  }

}

private struct HomeFeatureSection: HTML, Sendable {
  let feature: HomeFeature
  var body: some HTML {
    section(
      .class("feature feature-\(feature.rawValue)"), .id(feature.rawValue)
    ) {
      div(.class("feature-inner wrap")) {
        div(.class("feature-copy reveal")) {
          p(.class("eyebrow")) { "\(feature.number) / \(feature.label)" }
          h2 { feature.headline }
          p(.class("feature-description")) { feature.description }
          p(.class("feature-detail")) { feature.detail }
          if feature == .shortcuts {
            div(
              .class("shortcut-demo"),
              .custom(name: "aria-label", value: "Control Alt Enter: next project step")
            ) {
              kbd { "ctrl" }
              kbd { "alt" }
              kbd { "enter" }
              span { "Next step" }
            }
          }
          if feature == .fittings {
            a(.class("quiet-link"), .href(route: .fittingReference(.init()))) {
              "Explore the fitting reference ↗"
            }
          }
          span(.class("feature-rule"), .custom(name: "aria-hidden", value: "true")) {}
        }
        div(.class("feature-visual reveal")) { HomeFeatureArt(feature: feature) }
      }
    }
  }
}

private struct HomeFeatureArt: HTML, Sendable {
  let feature: HomeFeature
  var body: some HTML {
    figure(.class("feature-art art-\(feature.rawValue)")) {
      HomeScreen(name: feature.image)
      figcaption(.class("art-caption")) {
        feature.caption
      }
    }
  }
}

private struct HomeScreen: HTML, Sendable {
  let name: String
  var hero = false

  private var dimensions: (width: Int, height: Int) {
    switch name {
    case "filters": (1000, 720)
    case "fittings": (1168, 997)
    default: (1200, 820)
    }
  }

  private var imageDescription: String {
    switch name {
    case "rooms": "Room heating and cooling loads imported into a sample DuctCalc project"
    case "paths": "Supply and return duct paths with fittings and total equivalent lengths"
    case "fittings": "Duct fitting drawings and equivalent length reference values"
    case "pressure": "Component pressure losses and calculated design friction rate"
    case "filters": "Filter pressure drops compared at the project's airflow"
    case "shortcuts": "Keyboard shortcuts for navigating and editing a DuctCalc project"
    default: "Calculated supply and return trunk sizes and room branch duct sizes"
    }
  }

  var body: some HTML {
    div(.class("screen-frame")) {
      picture {
        source(
          .custom(name: "media", value: "(prefers-color-scheme: dark)"),
          .custom(name: "srcset", value: "/images/home/\(name)-dark.jpg"))
        img(
          .src("/images/home/\(name)-light.jpg"), .alt(imageDescription),
          .width(dimensions.width), .height(dimensions.height),
          .custom(name: "loading", value: hero ? "eager" : "lazy"),
          .custom(name: "decoding", value: "async")
        )
        .attributes(.custom(name: "fetchpriority", value: "high"), when: hero)
      }
    }
  }
}

private enum HomeFeature: String, CaseIterable, Sendable {
  case loads, paths, fittings, pressure, filters, shortcuts, sizes

  var number: String { "0\(Self.allCases.firstIndex(of: self)! + 1)" }
  var image: String { self == .loads ? "rooms" : rawValue }
  var shortTitle: String {
    switch self {
    case .loads: "Room loads"
    case .paths: "TEL templates"
    case .fittings: "Fittings"
    case .pressure: "Friction rate"
    case .filters: "Filters"
    case .shortcuts: "Shortcuts"
    case .sizes: "Duct sizes"
    }
  }
  var label: String { shortTitle.uppercased() }
  var headline: String {
    switch self {
    case .loads: "You already did\nthe load calc."
    case .paths: "Your usual paths.\nReady to reuse."
    case .fittings: "The right fitting.\nRight in front of you."
    case .pressure: "Every pressure loss\nhas a place."
    case .filters: "Pick the filter\nfor the airflow."
    case .shortcuts: "Keep your hands\non the keys."
    case .sizes: "Finish the design.\nTake it to the job."
    }
  }
  var description: String {
    switch self {
    case .loads:
      "Bring it with you. Import room loads from a current or legacy CoolCalc PDF and get straight to the duct design."
    case .paths:
      "Save total equivalent length paths for the duct systems you design often. Start the next job with your familiar fittings and straight lengths."
    case .fittings:
      "Browse drawings and reference conditions as you build a duct path. Put the fittings you actually use into the calculation."
    case .pressure:
      "Work from equipment static pressure through the component losses to available static pressure and design friction rate."
    case .filters:
      "Look up pressure drop at the project's airflow. Keep favorites close so choosing the filter is part of the design."
    case .shortcuts:
      "Move between rooms, equipment, paths, and duct sizes without reaching for the mouse at every step."
    case .sizes:
      "Work through round and rectangular duct sizes, then export a PDF that brings the project's calculations together."
    }
  }
  var detail: String {
    switch self {
    case .loads:
      "Room-by-room heating and cooling loads stay together, ready for the rest of the Manual-D workflow."
    case .paths: "Templates save the setup. You still adjust the path to the job in front of you."
    case .fittings:
      "Equivalent lengths and the conditions behind them sit alongside the drawings. The same reference is available without an account."
    case .pressure:
      "Friction rate templates carry your repeat setups forward, with each component loss still visible."
    case .filters:
      "Compare filters from your library and carry the selected pressure loss into the friction rate calculation."
    case .shortcuts:
      "Find a room, add an item, or jump to the next step. Shortcuts are customizable. The mouse works too."
    case .sizes:
      "A browser-based workspace from the first room load to the report you take with you."
    }
  }
  var caption: String {
    switch self {
    case .loads: "Current and legacy CoolCalc PDFs"
    case .paths: "Your fittings. Your repeatable setups."
    case .fittings: "Drawings + equivalent lengths + conditions"
    case .pressure: "See how the friction rate comes together"
    case .filters: "Pressure drop at your project's airflow"
    case .shortcuts: "Keyboard shortcuts throughout the app"
    case .sizes: "Round and rectangular duct sizing"
    }
  }
}
