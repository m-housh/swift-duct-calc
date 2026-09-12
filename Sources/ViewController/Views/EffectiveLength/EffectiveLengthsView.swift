import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthsView: HTML, Sendable {
  @Environment(ProjectViewValue.$projectID) var projectID
  let effectiveLengths: [EquivalentLength]
  var coolingCFM: Int?

  static func ranked(_ paths: [EquivalentLength]) -> [EquivalentLength] {
    paths.sorted {
      $0.totalEquivalentLength == $1.totalEquivalentLength
        ? $0.id.uuidString < $1.id.uuidString : $0.totalEquivalentLength > $1.totalEquivalentLength
    }
  }
  var supplies: [EquivalentLength] { Self.ranked(effectiveLengths.filter { $0.type == .supply }) }
  var returns: [EquivalentLength] { Self.ranked(effectiveLengths.filter { $0.type == .return }) }

  private var selectedID: EquivalentLength.ID? { supplies.first?.id ?? returns.first?.id }

  var body: some HTML {
    div(.data("tel-workspace", value: "")) {
      PageTitleRow {
        div {
          PageTitle { "Total effective length" }
          p(.class("muted")) {
            "The longest supply and return paths set TEL. Expand fittings in the table to inspect each path."
          }
        }
        div(.class("row-actions")) {
          a(.class("btn btn-outline"), .href(pathTemplatesURL(projectID))) { "Manage templates" }
          a(
            .class("btn btn-primary"), .init(name: "aria-label", value: "Add path"),
            .href("/projects/\(projectID)/effective-lengths/editor")
          ) {
            SVG(.circlePlus)
            "Add path"
          }
        }
      }
      div(.class("project-panel tel-equation")) {
        div {
          strong {
            if let path = returns.first {
              Number(path.totalEquivalentLength, digits: 1)
            } else {
              "—"
            }
          }
          small { "ft · longest return path" }
        }
        span { "+" }
        div {
          strong {
            if let path = supplies.first {
              Number(path.totalEquivalentLength, digits: 1)
            } else {
              "—"
            }
          }
          small { "ft · longest supply path" }
        }
        span { "=" }
        div {
          strong(.class("tel-result")) {
            if let ret = returns.first, let sup = supplies.first {
              Number(ret.totalEquivalentLength + sup.totalEquivalentLength, digits: 1)
            } else {
              "Not set"
            }
          }
          small { "ft · total effective length" }
        }
      }
      details(
        .class("project-panel path-canvas"), .init(name: "open", value: ""),
        .data("expansion", value: "path-network")
      ) {
        summary(.class("canvas-legend")) {
          span(.class("network-toggle")) {
            SVG(.chevronRight)
            "PATH NETWORK"
          }
          span {
            "Longest supply and return · All \(effectiveLengths.count) paths in the table below"
          }
        }
        div(.class("path-network")) {
          HTMLRaw(
            "<svg class=\"network-wires\" viewBox=\"0 0 1200 480\" preserveAspectRatio=\"none\" aria-hidden=\"true\">"
          )
          for (side, paths) in [returns, supplies].enumerated() {
            HTMLRaw(
              "<path class=\"\(side == 0 ? "return" : "supply") missing-wire\" d=\"M600 240 C\(side == 0 ? 430 : 770) 240,\(side == 0 ? 430 : 770) \(paths.isEmpty ? 144 : 360),\(side == 0 ? 192 : 1008) \(paths.isEmpty ? 144 : 360)\"/>"
            )
            if let path = paths.first {
              HTMLRaw(
                "<path class=\"\(path.type.rawValue)\(path.id == selectedID ? " selected-wire" : "")\" data-path-wire=\"\(path.id.idString)\" d=\"M600 240 C\(side == 0 ? 430 : 770) 240,\(side == 0 ? 430 : 770) 144,\(side == 0 ? 192 : 1008) 144\"/>"
              )
            }
          }
          HTMLRaw("</svg>")
          a(
            .class("network-handler"),
            .href(route: .project(.detail(projectID, .equipment(.index))))
          ) {
            SVG(.fan)
            strong { "Air handler" }
            span {
              if let coolingCFM {
                Number(coolingCFM)
                " CFM"
              } else {
                "Equipment not set"
              }
            }
          }
          for (side, paths) in [returns, supplies].enumerated() {
            AddPathCard(
              projectID: projectID, type: side == 0 ? .return : .supply,
              side: side, hasPath: !paths.isEmpty)
            if let path = paths.first {
              article(
                .class("network-endpoint \(path.type.rawValue) governing"),
                .style("left:\(side == 0 ? 16 : 84)%;top:30%")
              ) {
                button(
                  .type(.button), .class("network-path-select"),
                  .data("select-path", value: path.id.idString),
                  .init(name: "aria-pressed", value: path.id == selectedID ? "true" : "false")
                ) {
                  span { "Longest \(path.type.rawValue) path" }
                  strong { path.name }
                  b {
                    Number(path.totalEquivalentLength, digits: 1)
                    small { " ft" }
                  }
                  small(.class("path-selection")) { "Selected" }
                }
                div(.class("network-path-actions")) {
                  EffectiveLengthsTable.PathActions(effectiveLength: path)
                }
              }
            }
          }
        }
      }
      section(.class("project-panel path-schedule")) {
        div(.class("path-schedule-heading")) {
          h2 {
            "All paths"
            span { "\(effectiveLengths.count)" }
          }
          div {
            span { "Select a row · Expand fittings to compare" }
          }
        }
        div(
          .class("table-scroll"), .tabindex(0), .role("region"),
          .init(name: "aria-label", value: "Equivalent lengths")
        ) {
          EffectiveLengthsTable(effectiveLengths: effectiveLengths)
        }
      }
    }
  }

  private struct AddPathCard: HTML, Sendable {
    let projectID: Project.ID
    let type: EquivalentLength.EffectiveLengthType
    let side: Int
    let hasPath: Bool

    var body: some HTML {
      a(
        .class("network-endpoint missing-path \(type.rawValue)"),
        .href(route: .project(.detail(projectID, .equivalentLength(.editor(nil, type: type))))),
        .style("left:\(side == 0 ? 16 : 84)%;top:\(hasPath ? 75 : 30)%"),
        .init(name: "aria-label", value: "Add \(type.rawValue) path")
      ) {
        span { "\(type.rawValue.capitalized) path" }
        strong { hasPath ? "Add another path" : "Required for TEL" }
        span(.class("missing-path-action")) {
          SVG(.circlePlus)
          "Add \(type.rawValue)"
        }
      }
    }
  }
}
