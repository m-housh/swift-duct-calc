import Elementary
import ManualDCore
import Styleguide

struct ProjectDetail: HTML, Sendable {
  let project: Project
  var detail: Project.Detail?
  var frictionRate: FrictionRate?

  private var tel: Double? {
    guard let detail,
      let supply = detail.equivalentLengths.filter({ $0.type == .supply }).map(
        \.totalEquivalentLength
      ).max(),
      let ret = detail.equivalentLengths.filter({ $0.type == .return }).map(\.totalEquivalentLength)
        .max()
    else { return nil }
    return supply + ret
  }

  var body: some HTML {
    div {
      PageTitleRow {
        div {
          PageTitle { "The whole design, connected." }
          p(.class("muted")) { "Select a part of the system to work on it." }
        }
        button(.type(.button), .class("btn btn-outline"), .showModal(id: ProjectForm.id)) {
          SVG(.squarePen)
          "Project details"
        }
      }
      section(.class("project-panel"), .init(name: "aria-label", value: "Project atlas")) {
        div(.class("canvas-legend")) {
          span { "PROJECT ATLAS" }
          span { "Five connected design sections" }
        }
        div(.class("project-atlas")) {
          HTMLRaw(
            """
            <svg class="atlas-wires" viewBox="0 0 1000 700" preserveAspectRatio="none" aria-hidden="true">
            <path d="M500 294L200 168 M500 294L750 119 M500 294L840 413 M500 294L500 623 M500 294L170 455"/>
            </svg>
            """)
          div(.class("atlas-house")) { ProjectHouse() }
          node("Room loads", icon: .doorClosed, position: "rooms", route: .rooms(.index)) {
            "\(detail?.rooms.count ?? 0) rooms"
          }
          node("Equipment", icon: .fan, position: "equipment", route: .equipment(.index)) {
            if let equipment = detail?.equipmentInfo {
              Number(equipment.coolingCFM)
              " CFM"
            } else {
              "Not set"
            }
          }
          node(
            "Duct paths", icon: .rulerDimensionLine, position: "paths",
            route: .equivalentLength(.index)
          ) {
            if let tel {
              Number(tel, digits: 1)
              " ft TEL"
            } else {
              "Not set"
            }
          }
          node(
            "Pressure", icon: .squareFunction, position: "friction", route: .frictionRate(.index)
          ) {
            if let frictionRate {
              if frictionRate.hasErrors {
                span(.class("text-error")) { "Invalid FR" }
              } else {
                Number(frictionRate.value, digits: 3)
                " FR"
              }
            } else {
              "Not set"
            }
          }
          node("Duct sizes", icon: .wind, position: "sizing", route: .ductSizing(.index)) {
            "\(detail?.rooms.filter { $0.delegatedTo == nil }.reduce(0) { $0 + $1.registerCount } ?? 0) registers"
          }
          aside(.class("project-house-sign"), .init(name: "aria-label", value: "Project details")) {
            h2 { project.name }
            p {
              project.streetAddress
              br()
              "\(project.city), \(project.state) \(project.zipCode)"
            }
          }
        }
      }
      ProjectForm(dismiss: true, project: project)
    }
  }

  private func node<C: HTML & Sendable>(
    _ label: String, icon: SVG.Key, position: String,
    route: SiteRoute.View.ProjectRoute.DetailRoute, @HTMLBuilder value: () -> C
  ) -> some HTML {
    a(.class("atlas-node atlas-\(position)"), .href(route: .project(.detail(project.id, route)))) {
      span(.class("node-icon")) { SVG(icon) }
      strong { value() }
      small { label }
    }
  }
}
