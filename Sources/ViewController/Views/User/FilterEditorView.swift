import Elementary
import Foundation
import ManualDCore
import Styleguide

struct FilterEditorView: HTML, Sendable {
  let library: FilterLibrary
  let filter: AirFilter?
  var duplicate = false
  private var draft: AirFilter {
    var value =
      filter
      ?? .init(
        id: "", manufacturer: "", model: "",
        points: [.init(airflow: 0, pressureDrop: 0), .init(airflow: 0, pressureDrop: 0)])
    if duplicate {
      value.model += " copy"
      value.id = ""
      value.source = nil
    }
    return value
  }
  var body: some HTML & Sendable {
    ModalForm(
      id: "filter-editor",
      title: duplicate ? "Duplicate filter" : filter == nil ? "Add filter" : "Edit filter",
      dismiss: true
    ) {
      form(
        .id("filter-editor-form"), .class("space-y-4"),
        .data("filter-draft", value: filterJSON(draft)),
        .data("filter-revision", value: library.revision.uuidString)
      ) {
        p(.data("filter-editor-error", value: ""), .role("alert")) {}
        if let source = draft.source,
          let original = AirFilter.defaults.first(where: { $0.source == source })
        {
          div(.class("rounded-box bg-base-200 p-3 space-y-2")) {
            p { "Shipped with DuctCalc from Aprilaire's chart." }
            button(
              .type(.button), .class("btn btn-sm btn-ghost"),
              .data("filter-reset", value: filterJSON(original))
            ) { "Reset to Aprilaire chart" }
          }
        }
        label(.class("flex items-center gap-2")) {
          input(.type(.checkbox), .class("checkbox checkbox-sm"), .name("favorite"))
            .attributes(.checked, when: !duplicate && library.favorites.contains(draft.id))
          "Add to favorite filters"
        }
        div(.class("grid gap-3 sm:grid-cols-2")) {
          label(.class("grid gap-1")) {
            span(.class("font-semibold")) { "Manufacturer" }
            input(
              .name("manufacturer"), .class("input w-full"), .value(draft.manufacturer),
              .init(name: "maxlength", value: "100"), .placeholder("e.g. Honeywell"))
          }
          label(.class("grid gap-1")) {
            span(.class("font-semibold")) { "Model or name" }
            input(
              .name("model"), .class("input w-full"), .value(draft.model), .required,
              .init(name: "maxlength", value: "100"))
          }
          label(.class("grid gap-1 sm:col-span-2")) {
            span(.class("font-semibold")) { "Description, optional" }
            input(
              .name("description"), .class("input w-full"), .value(draft.description),
              .init(name: "maxlength", value: "300"), .placeholder("e.g. MERV 13 · 20 x 25 x 4 in.")
            )
          }
        }
        h3(.id("filter-chart-label"), .class("font-semibold")) { "Pressure drop chart" }
        p(.class("muted text-sm")) {
          "The highest airflow is the filter's maximum recommended airflow. Values between points are interpolated."
        }
        div(
          .class("table-scroll filter-chart"), .tabindex(0), .role("region"),
          .init(name: "aria-labelledby", value: "filter-chart-label")
        ) {
          table(.class("table project-table")) {
            thead {
              tr {
                th { "Airflow · CFM" }
                th { "Pressure drop · in. w.c." }
                th { span(.class("sr-only")) { "Actions" } }
              }
            }
            tbody(.data("filter-points", value: "")) {
              for (index, point) in draft.points.enumerated() {
                FilterPointRow(point: point, index: index)
              }
            }
          }
        }
        button(
          .type(.button), .class("btn btn-outline btn-sm"), .data("filter-add-point", value: "")
        ) {
          SVG(.circlePlus)
          "Add airflow point"
        }
        details(.class("rounded-box border border-base-300 p-3")) {
          summary(.class("font-semibold")) { "Fill from a chart row" }
          div(.class("grid gap-3 mt-3")) {
            p(.class("muted text-sm")) {
              "For evenly spaced airflow columns. Filling replaces the points above."
            }
            label(.class("grid gap-1")) {
              span { "First airflow · CFM" }
              input(
                .name("firstAirflow"), .type(.number), .class("input w-full"), .value("400"),
                .min("1"), .max("100000"), .step("1"))
            }
            label(.class("grid gap-1")) {
              span { "Step · CFM" }
              input(
                .name("airflowStep"), .type(.number), .class("input w-full"), .value("200"),
                .min("1"), .max("100000"), .step("1"))
            }
            label(.class("grid gap-1")) {
              span { "Pressure drops, in order" }
              textarea(
                .name("chartValues"), .class("textarea w-full"), .init(name: "rows", value: "2"),
                .placeholder("0.06 0.09 0.13 0.17 0.23")
              ) {}
            }
            button(
              .type(.button), .class("btn btn-outline btn-sm"),
              .data("filter-fill-chart", value: "")
            ) { "Fill chart" }
          }
        }
        div(.class("flex flex-wrap gap-2 items-center")) {
          label(.class("flex items-center gap-2")) {
            span { "Check airflow" }
            input(
              .name("checkAirflow"), .class("input w-28"), .type(.number), .min("1"),
              .max("100000"), .step("1"), .value("1200"))
            span { "CFM" }
          }
          button(
            .type(.button), .class("btn btn-outline btn-sm"), .data("filter-preview", value: "")
          ) { "Check chart" }
        }
        div(.id("filter-chart-preview"), .role("status")) { "Complete the chart to check a value." }
        div(.class("flex justify-end gap-2")) {
          button(
            .type(.button), .class("btn btn-ghost"), .on(.click, "this.closest('dialog').close()")
          ) { "Cancel" }
          button(.type(.submit), .class("btn btn-primary")) { "Save filter" }
        }
      }
    }
  }
}
struct FilterPointRow: HTML, Sendable {
  let point: AirFilter.Point
  let index: Int
  var body: some HTML & Sendable {
    tr {
      td {
        input(
          .type(.number), .class("input input-sm"), .name("pointAirflow"), .min("1"),
          .max("100000"), .step("1"), .required,
          .value(point.airflow == 0 ? "" : String(point.airflow)),
          .init(name: "aria-label", value: "Airflow for point \(index + 1)"))
      }
      td {
        input(
          .type(.number), .class("input input-sm"), .name("pointDrop"), .min("0.001"), .max("1"),
          .step("any"), .required,
          .value(point.pressureDrop == 0 ? "" : String(point.pressureDrop)),
          .init(name: "aria-label", value: "Pressure drop for point \(index + 1)"))
      }
      td {
        button(
          .type(.button), .class("btn btn-ghost btn-sm"), .data("filter-remove-point", value: ""),
          .init(name: "aria-label", value: "Remove point \(index + 1)")
        ) { SVG(.trash) }
      }
    }
  }
}
struct FilterChartResult: HTML, Sendable {
  let filter: AirFilter
  let airflow: Int
  var body: some HTML & Sendable {
    div {
      strong { "\(filterNumber(filter.pressureDrop(at: airflow))) in. w.c." }
      if airflow > filter.maxCFM { span(.class("badge badge-warning")) { "Over max CFM" } }
      if zip(filter.points, filter.points.dropFirst()).contains(where: {
        $0.pressureDrop > $1.pressureDrop
      }) {
        p(.class("alert alert-warning")) {
          "Pressure drop decreases as airflow increases. Check for a typo."
        }
      }
      p(.class("muted text-sm")) {
        "Values between points are interpolated. Outside the chart, the end segments are extended. Results round up to 0.01 in. w.c."
      }
    }
  }
}
