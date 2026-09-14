import Dependencies
import Elementary
import Foundation
import ManualDCore
import Styleguide

extension PdfClient.Request {
  func toHTML() -> (some HTML & Sendable) {
    @Dependency(\.date.now) var now
    return PdfDocument(request: self, generatedAt: now)
  }
}

struct PdfDocument: HTMLDocument {
  let lang = "en"
  let request: PdfClient.Request
  let generatedAt: Date

  var title: String { "\(request.project.name) · Duct design report" }
  var date: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "MMMM d, yyyy"
    return formatter.string(from: generatedAt)
  }

  var head: some HTML {
    meta(.charset(.utf8))
    link(.rel(.stylesheet), .href("css/pdf.css"))
  }

  var body: some HTML {
    header(.class("masthead")) {
      DuctCalcWordmark(printMarkSource: "images/brand/ductcalc-mark-dark.webp")
      span(.class("report-type")) { "Residential duct design" }
    }
    main {
      article(.class("report-section")) {
        reportHeading(number: "01", title: "Duct schedule")
        div(.class("summary")) {
          metric(
            "Heating airflow", value: request.equipmentInfo.heatingCFM?.string() ?? "—", unit: "CFM"
          )
          metric(
            "Cooling airflow", value: request.equipmentInfo.coolingCFM?.string() ?? "—", unit: "CFM"
          )
          metric(
            "Design friction rate", value: request.frictionRate.value.string(digits: 3),
            unit: "in. w.c. / 100 ft")
        }
        if let error = request.frictionRate.error {
          div(.class("error"), .role("alert")) {
            strong { error.reason }
            ul { for resolution in error.resolutions { li { resolution } } }
          }
        }
        section {
          sectionHeading("Room ducts", detail: "Dimensions in inches · Airflow per register")
          DuctSizesTable(rooms: request.ductSizes.rooms)
        }
        section {
          sectionHeading("Trunks & runouts")
          TrunkTable(sizes: request.ductSizes)
        }
        p(.class("note")) {
          "Highlighted values show final round size or rectangular height and width, in inches."
          br()
          "A dash indicates no rectangular size. Room suffixes identify individual registers."
        }
      }
      article(.class("report-section")) {
        reportHeading(number: "02", title: "Design calculations")
        div(.class(compactLosses ? "columns" : "")) {
          section {
            sectionHeading("Equipment")
            EquipmentTable(equipmentInfo: request.equipmentInfo, projectSHR: request.projectSHR)
            p(.class("note")) {
              "Pressure remaining after component losses is available to move air through the duct system."
            }
          }
          section {
            sectionHeading("Component pressure losses")
            FrictionRateTable(componentLosses: request.componentLosses)
          }
        }
        formula(
          "Available static pressure",
          detail:
            "\(request.equipmentInfo.staticPressure.string()) external static − \(request.componentLosses.reduce(0) { $0 + $1.value }.string()) component losses",
          value: request.frictionRate.availableStaticPressure.string(), unit: "in. w.c."
        )
        section {
          sectionHeading("Controlling duct paths", detail: "Longest supply + longest return")
          div(.class(compactPaths ? "columns" : "")) {
            EffectiveLengthTable(path: request.maxSupplyTEL)
            EffectiveLengthTable(path: request.maxReturnTEL)
          }
        }
        formula(
          "Design friction rate",
          detail:
            "\(request.frictionRate.availableStaticPressure.string()) in. w.c. × 100 ÷ \(request.totalEquivalentLength.string()) ft total equivalent length",
          value: request.frictionRate.value.string(digits: 3), unit: "in. w.c. / 100 ft"
        )
        p(.class("note")) {
          "TEL includes straight duct and fitting equivalent lengths. The controlling supply and return paths total \(request.totalEquivalentLength.string()) ft."
        }
      }
      article(.class("report-section")) {
        reportHeading(number: "03", title: "Loads & airflow")
        section {
          sectionHeading("Room loads", detail: "Sensible heat ratio \(request.projectSHR.string())")
          RoomsTable(rooms: request.rooms, projectSHR: request.projectSHR)
        }
        section {
          sectionHeading("Register airflow", detail: "Loads and airflow per register")
          RegisterDetailTable(rooms: request.ductSizes.rooms)
        }
        p(.class("note")) {
          "Design airflow is the larger of the heating and cooling requirements for each register."
          br()
          "Displayed values are rounded. Register design airflows may sum to more than either equipment airflow."
        }
      }
    }
  }

  // Side-by-side blocks cannot fragment reliably in the PDF renderer. Longer tables use normal flow.
  private var compactLosses: Bool {
    request.componentLosses.count <= 6 && request.componentLosses.allSatisfy { $0.name.count <= 50 }
  }
  private var compactPaths: Bool {
    [request.maxSupplyTEL, request.maxReturnTEL].allSatisfy {
      $0.groups.count <= 6 && $0.straightLengths.count <= 6 && $0.name.count <= 50
    }
  }

  @HTMLBuilder private func reportHeading(number: String, title: String) -> some HTML {
    div(.class("report-heading")) {
      p(.class("eyebrow")) { "\(number) / Design report" }
      h1 { title }
      div(.class("project")) {
        div {
          strong(.class("project-name")) { request.project.name }
          p {
            "\(request.project.streetAddress) · \(request.project.city), \(request.project.state) \(request.project.zipCode)"
          }
        }
        div(.class("meta")) {
          strong { "Generated" }
          p { date }
        }
      }
    }
  }

  @HTMLBuilder private func sectionHeading(_ title: String, detail: String = "") -> some HTML {
    div(.class("section-heading")) {
      h2 { title }
      if !detail.isEmpty { span { detail } }
    }
  }

  @HTMLBuilder private func metric(_ title: String, value: String, unit: String) -> some HTML {
    div(.class("metric")) {
      span { title }
      strong { value }
      small { unit }
    }
  }

  @HTMLBuilder private func formula(_ title: String, detail: String, value: String, unit: String)
    -> some HTML
  {
    div(.class("formula")) {
      div {
        b { title }
        span { detail }
      }
      strong {
        value
        small { unit }
      }
    }
  }
}
