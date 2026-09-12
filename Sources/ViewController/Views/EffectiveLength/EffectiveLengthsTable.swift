import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthsTable: HTML, Sendable {
  let effectiveLengths: [EquivalentLength]
  var body: some HTML<HTMLTag.table> {
    table(.class("table project-table path-table"), .data("selectable-table", value: "paths")) {
      thead {
        tr {
          th { "Path" }
          th { "System" }
          th { "Straight · ft" }
          th { "Fittings · ft" }
          th { "Total · ft" }
          th { "Fitting breakdown" }
          th { span(.class("sr-only")) { "Actions" } }
        }
      }
      tbody {
        for type in [EquivalentLength.EffectiveLengthType.supply, .return] {
          let paths = EffectiveLengthsView.ranked(effectiveLengths.filter { $0.type == type })
          for path in paths {
            EffectiveLengthRow(
              effectiveLength: path,
              longest: path.totalEquivalentLength == paths.first?.totalEquivalentLength)
          }
        }
      }
    }
  }

  struct EffectiveLengthRow: HTML, Sendable {
    let effectiveLength: EquivalentLength
    var longest = false
    var body: some HTML<HTMLTag.tr> {
      tr(.id(effectiveLength.id.idString), .data("record", value: effectiveLength.id.idString)) {
        td {
          button(.type(.button), .class("row-select"), .init(name: "aria-pressed", value: "false"))
          {
            effectiveLength.name
          }
          if longest {
            span(.class("longest-badge \(effectiveLength.type.rawValue)")) { "Longest" }
          }
        }
        td {
          span(.class("system-label \(effectiveLength.type.rawValue)")) {
            effectiveLength.type.rawValue.capitalized
          }
        }
        td {
          if effectiveLength.straightLengths.count > 1 {
            details(.data("expansion", value: "straight-\(effectiveLength.id.idString)")) {
              summary { Number(effectiveLength.straightLengths.reduce(0, +)) }
              for length in effectiveLength.straightLengths { p { "\(length) ft" } }
            }
          } else {
            Number(effectiveLength.straightLengths.reduce(0, +))
          }
        }
        td { Number(effectiveLength.groups.totalEquivalentLength, digits: 1) }
        td { strong { Number(effectiveLength.totalEquivalentLength, digits: 1) } }
        td {
          details(
            .class("fitting-breakdown"),
            .data("expansion", value: "fittings-\(effectiveLength.id.idString)")
          ) {
            summary {
              "\(effectiveLength.groups.reduce(0) { $0 + $1.quantity }) fittings · \(Set(effectiveLength.groups.map(\.group)).count) groups"
            }
            for groupNumber in Set(effectiveLength.groups.map(\.group)).sorted() {
              h3 { "Group \(groupNumber)" }
              for fitting in effectiveLength.groups.filter({ $0.group == groupNumber }) {
                div(.class("fitting-line")) {
                  span {
                    if let name = fitting.fitting?.name {
                      span { name }
                      br()
                    }
                    span {
                      fitting.letter.isEmpty
                        ? "Group \(fitting.group)" : "\(fitting.group)-\(fitting.letter)"
                    }
                  }
                  span {
                    Number(fitting.value, digits: 2)
                    " ft × \(fitting.quantity)"
                  }
                  strong {
                    Number(fitting.value * Double(fitting.quantity), digits: 2)
                    " ft"
                  }
                }
              }
            }
          }
        }
        td {
          PathActions(effectiveLength: effectiveLength)
        }
      }
    }
  }

  struct PathActions: HTML, Sendable {
    let effectiveLength: EquivalentLength
    var body: some HTML {
      div(.class("row-actions")) {
        a(
          .class("btn btn-ghost"),
          .title("Duplicate path"),
          .init(name: "aria-label", value: "Duplicate \(effectiveLength.name)"),
          .href(
            route: .project(
              .detail(
                effectiveLength.projectID, .equivalentLength(.duplicate(effectiveLength.id)))))
        ) { SVG(.copy) }
        TrashButton("Delete \(effectiveLength.name)").attributes(
          .class("btn-ghost"), .title("Delete path"),
          .hx.delete(
            route: .project(
              .detail(
                effectiveLength.projectID, .equivalentLength(.delete(id: effectiveLength.id))))),
          .hx.confirm("Delete this path?"), .hx.target("body"), .hx.swap(.outerHTML))
        a(
          .class("btn btn-ghost"),
          .title("Edit path"),
          .init(name: "aria-label", value: "Edit \(effectiveLength.name)"),
          .href(
            "/projects/\(effectiveLength.projectID)/effective-lengths/editor?id=\(effectiveLength.id)"
          )
        ) { SVG(.squarePen) }
      }
    }
  }
}
