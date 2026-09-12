import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct FrictionRateView: HTML, Sendable {
  @Environment(ProjectViewValue.$projectID) var projectID
  let componentLosses: [ComponentPressureLoss]
  let equivalentLengths: EquivalentLength.MaxContainer
  let frictionRate: FrictionRate?
  var blowerStatic: Double?

  private var sortedLosses: [ComponentPressureLoss] {
    componentLosses.sorted {
      $0.value == $1.value ? $0.id.uuidString < $1.id.uuidString : $0.value > $1.value
    }
  }
  private func share(_ loss: ComponentPressureLoss) -> Double? {
    guard let blowerStatic, blowerStatic > 0 else { return nil }
    return loss.value / blowerStatic * 100
  }
  private func y(_ position: Int) -> Double {
    60 + Double(position) * 360 / Double(max(sortedLosses.count - 1, 1))
  }

  var body: some HTML {
    div(.data("pressure-workspace", value: "")) {
      PageTitleRow {
        div {
          PageTitle { "Where the pressure goes" }
          p(.class("muted")) { "The width of each stream represents its share of blower static." }
        }
        button(.type(.button), .class("btn btn-outline"), .showModal(id: ComponentLossForm.id())) {
          SVG(.circlePlus)
          "Add component"
        }
      }
      summaryMetrics
      pressureFlow
      componentTable
      if frictionRate == nil {
        Alert { "Complete equipment and supply/return paths to calculate friction rate." }
      }
      ComponentLossForm(dismiss: true, projectID: projectID, componentLoss: nil)
      for loss in sortedLosses {
        ComponentLossForm(dismiss: true, projectID: projectID, componentLoss: loss)
      }
    }
  }

  private var summaryMetrics: some HTML {
    div(.class("design-metrics pressure-summary")) {
      DesignMetric(
        "Blower static", value: blowerStatic.map { String(format: "%.2f", $0) } ?? "Not set",
        unit: "in. w.c.")
      DesignMetric(
        "Total effective length",
        value: equivalentLengths.totalEquivalentLength.map { String(format: "%g", $0) }
          ?? "Not set",
        unit: "ft")
      DesignMetric(
        "Design friction rate",
        value: frictionRate.map { $0.value.isFinite ? String(format: "%.3f", $0.value) : "Invalid" }
          ?? "Not set",
        unit: "in. w.c. / 100 ft", error: frictionRate?.error?.reason)
    }
  }

  private var pressureFlow: some HTML {
    details(
      .class("project-panel pressure-canvas"), .init(name: "open", value: ""),
      .data("expansion", value: "pressure-flow")
    ) {
      summary(.class("canvas-legend")) {
        span(.class("network-toggle")) {
          SVG(.chevronRight)
          "PRESSURE FLOW"
        }
        span { "Select a component · All losses in the table below" }
      }
      div(
        .class("pressure-river"), .style("--river-height: \(max(500, sortedLosses.count * 160))px")
      ) {
        HTMLRaw(
          "<svg class=\"river-wires\" viewBox=\"0 0 1000 490\" preserveAspectRatio=\"none\" aria-hidden=\"true\">"
        )
        HTMLRaw("<path class=\"pressure-source-line\" d=\"M100 50V445\"/>")
        for (index, loss) in sortedLosses.enumerated() {
          HTMLRaw(
            "<path class=\"loss-stream\(index == 0 ? " active" : "")\" data-loss-stream=\"\(loss.id.idString)\" d=\"M115 245 C420 245,430 \(y(index)),770 \(y(index))\" style=\"stroke-width:\(min(160, max(1, (share(loss) ?? 0) * 1.6)))\"/>"
          )
        }
        HTMLRaw("</svg>")
        div(.class("pressure-source")) {
          span { "BLOWER STATIC" }
          strong {
            if let blowerStatic {
              blowerStatic.formatted(.number.precision(.fractionLength(2)))
            } else {
              "Not set"
            }
          }
          small { "in. w.c." }
        }
        for (index, loss) in sortedLosses.enumerated() {
          article(
            .class("river-endpoint"), .style("top: \(y(index) / 490 * 100)%")
          ) {
            button(
              .type(.button), .class("loss-card-select"),
              .data("select-loss", value: loss.id.idString),
              .init(name: "aria-pressed", value: index == 0 ? "true" : "false")
            ) {
              span {
                loss.name
                small {
                  if let percent = share(loss) {
                    Number(percent, digits: 1)
                    "% of blower static"
                  } else {
                    "Blower static not set"
                  }
                }
              }
              strong { loss.value.formatted(.number.precision(.fractionLength(2))) }
            }
            div(.class("loss-card-actions row-actions")) {
              LossActions(projectID: projectID, loss: loss)
            }
          }
        }
        if sortedLosses.isEmpty {
          p(.class("empty-state")) { "Add component pressure losses to complete this section." }
        }
      }
    }
  }

  private var componentTable: some HTML {
    section(.class("project-panel loss-schedule")) {
      div(.class("path-schedule-heading")) {
        h2 {
          "Component losses"
          span { "\(sortedLosses.count)" }
        }
        span(.class("muted")) { "Highest share first · Edit pressure losses inline" }
      }
      div(
        .class("table-scroll"), .tabindex(0), .role("region"),
        .init(name: "aria-label", value: "Component pressure losses")
      ) {
        table(.class("table project-table loss-table"), .data("selectable-table", value: "loss")) {
          thead {
            tr {
              th { "Component" }
              th { "Pressure loss · in. w.c." }
              th { "% of blower static" }
              th { span(.class("sr-only")) { "Actions" } }
            }
          }
          tbody {
            for loss in sortedLosses {
              tr(.data("record", value: loss.id.idString)) {
                td {
                  button(
                    .type(.button), .class("row-select"),
                    .init(name: "aria-pressed", value: "false")
                  ) { loss.name }
                }
                td {
                  form(
                    .class("loss-inline-form"), .data("loss-form", value: loss.id.idString),
                    .data("success-message", value: "Component loss saved."),
                    .hx.patch(
                      route: .project(
                        .detail(
                          projectID,
                          .componentLoss(
                            .update(loss.id, .init(name: loss.name, value: loss.value)))))),
                    .hx.target("body"), .hx.swap(.outerHTML)
                  ) {
                    input(.type(.hidden), .name("name"), .value(loss.name))
                    input(.type(.hidden), .name("projectID"), .value("\(projectID)"))
                    input(
                      .class("input"), .type(.number), .name("value"),
                      .value(String(format: "%.2f", loss.value)),
                      .init(name: "aria-label", value: "Pressure loss for \(loss.name)"),
                      .min("0.03"), .max("1"), .step("0.01"), .required)
                    button(.type(.submit), .class("btn btn-primary")) { "Apply loss" }
                  }
                }
                td {
                  if let percent = share(loss) {
                    Number(percent, digits: 1)
                    "%"
                  } else {
                    span(.class("muted")) { "Not set" }
                  }
                }
                td { LossActions(projectID: projectID, loss: loss) }
              }
            }
            if sortedLosses.isEmpty {
              tr {
                td(.init(name: "colspan", value: "4"), .class("empty-state")) {
                  "Add a component to enter its pressure loss."
                }
              }
            }
          }
        }
      }
    }
  }

  private struct LossActions: HTML, Sendable {
    let projectID: Project.ID
    let loss: ComponentPressureLoss
    var body: some HTML {
      div(.class("row-actions")) {
        EditButton(accessibilityLabel: "Edit \(loss.name)").attributes(
          .class("btn-ghost"), .title("Edit component"),
          .showModal(id: ComponentLossForm.id(loss)))
        TrashButton("Delete \(loss.name)").attributes(
          .class("btn-ghost"), .title("Delete component"),
          .hx.delete(route: .project(.detail(projectID, .componentLoss(.delete(loss.id))))),
          .hx.confirm("Delete this component loss?"), .hx.target("body"), .hx.swap(.outerHTML))
      }
    }
  }
}
