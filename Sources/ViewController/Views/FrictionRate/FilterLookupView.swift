import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct FilterLookupView: HTML, Sendable {
  static let id = "filterLookup"
  let projectID: Project.ID
  let airflow: Int?
  let componentLosses: [ComponentPressureLoss]
  var library = FilterLibrary()
  var allowance: Double?
  var template: FrictionRateTemplate?
  private var filterComponents: [ComponentPressureLoss] {
    componentLosses.filter { $0.name.localizedCaseInsensitiveContains("filter") }
      .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
  }
  var body: some HTML & Sendable {
    ModalForm(
      id: Self.id, title: template == nil ? "Look up filter pressure drop" : "Add a filter",
      dismiss: true
    ) {
      div(
        .data("filter-auto-open", value: template == nil ? "false" : "true"),
        .data("filter-results-url", value: "/projects/\(projectID)/friction-rate/filter-results")
      ) {
        if let template {
          p(.class("alert alert-success mb-4")) {
            "\(template.name) applied. Add a filter or skip this step."
          }
        }
        if let airflow {
          form(
            .class("space-y-4"), .id("filter-lookup-form"),
            .hx.post(
              route: .project(.detail(projectID, .frictionRate(.applyFilter(.init(model: "")))))),
            .hx.target("body"), .hx.swap(.outerHTML), .init(name: "hx-sync", value: "this:drop"),
            .data("success-message", value: "Filter pressure loss saved.")
          ) {
            p(.class("muted")) {
              "Pressure drops from your filter library at \(airflow.string()) CFM, the larger heating or cooling airflow. Values are copied. Look up the filter again if airflow changes."
            }
            label(.class("grid gap-2")) {
              span(.class("font-semibold")) { "Filter loss included in equipment rating" }
              span(.class("flex items-center gap-2")) {
                input(
                  .type(.number), .name("allowance"), .class("input w-28"), .min("0.01"), .max("1"),
                  .step("0.01"), .placeholder("None"), .value(allowance.map(filterNumber) ?? ""),
                  .data("filter-allowance", value: ""),
                  .init(name: "aria-describedby", value: "filter-allowance-help"))
                span { "in. w.c." }
              }
            }
            p(.id("filter-allowance-help"), .class("muted text-sm")) {
              "Optional. Leave blank if the rating doesn't include a filter. Only the filter loss above this is added."
            }
            if !filterComponents.isEmpty { destination }
            div(.data("filter-results", value: "")) {
              FilterLookupResults(library: library, airflow: airflow, allowance: allowance)
            }
          }
        } else {
          p(.class("muted mb-4")) { "Enter heating or cooling airflow in Equipment first." }
          a(
            .class("btn btn-primary"),
            .href(route: .project(.detail(projectID, .equipment(.index))))
          ) { "Go to equipment" }
        }
        div(.class("flex flex-wrap justify-between gap-2 mt-4")) {
          a(.class("btn btn-ghost"), .href("/filters"), .target(.blank), .rel("noopener")) {
            "Manage filters"
          }
          if template != nil {
            button(
              .type(.button), .class("btn btn-outline"),
              .on(.click, "this.closest('dialog').close()")
            ) { "Skip filter" }
          }
        }
      }
    }
  }
  private var destination: some HTML & Sendable {
    fieldset(.class("fieldset border border-base-300 rounded-box px-4 py-2")) {
      legend(.class("fieldset-legend")) { "Save as" }
      for (index, loss) in filterComponents.enumerated() {
        label(.class("flex items-center gap-2")) {
          input(
            .type(.radio), .class("radio radio-sm"), .name("replacing"), .value(loss.id.uuidString)
          ).attributes(.checked, when: index == 0)
          "Replace \(loss.name) (\(filterNumber(loss.value)))"
        }
      }
      label(.class("flex items-center gap-2")) {
        input(.type(.radio), .class("radio radio-sm"), .name("replacing"), .value(""))
        "Add as another component"
      }
    }
  }
}

struct FilterLookupResults: HTML, Sendable {
  let library: FilterLibrary
  let airflow: Int?
  let allowance: Double?
  var body: some HTML & Sendable {
    div(.data("filter-revision", value: library.revision.uuidString), .class("space-y-4")) {
      if let airflow {
        if let filter = library.suggestion(at: airflow) {
          div(.class("rounded-box bg-base-200 p-4 flex flex-wrap justify-between gap-3")) {
            div {
              small(.class("block muted")) { "Suggested" }
              strong { filter.name }
              p(.class("text-sm")) {
                "\(filterNumber(added(filter, airflow))) added · \(filterNumber(filter.pressureDrop(at: airflow))) chart"
              }
            }
            FilterUseButton(
              filter: filter, airflow: airflow, allowance: allowance, title: "Use \(filter.name)")
          }
        } else if !library.favorites.isEmpty {
          p(.class("muted")) {
            "No favorite meets your pressure drop and airflow limits. Choose a filter below."
          }
        }
        if library.filters.isEmpty {
          p { "Your filter library is empty. Add a filter in Account → Filter library." }
        } else {
          label(.class("flex items-center gap-2")) {
            input(
              .type(.checkbox), .class("toggle toggle-sm"), .data("filter-hide-over", value: ""))
            "Hide filters over \(library.maximumPressureDrop.map { "\(filterNumber($0)) in. w.c. or " } ?? "")max CFM"
          }
          div(
            .class("table-scroll"), .tabindex(0), .role("region"),
            .init(name: "aria-label", value: "Filter pressure drops")
          ) {
            table(.class("table project-table")) {
              thead {
                tr {
                  th { span(.class("sr-only")) { "Favorite" } }
                  th { "Filter" }
                  th(.class("text-right")) { allowance == nil ? "in. w.c." : "Added · in. w.c." }
                  th { span(.class("sr-only")) { "Actions" } }
                }
              }
              tbody {
                tr {
                  th(.init(name: "colspan", value: "4"), .scope(.rowgroup), .class("bg-base-200")) {
                    "Preferred"
                  }
                }
                for filter in library.preferredFilters {
                  Row(library: library, filter: filter, airflow: airflow, allowance: allowance)
                }
              }
              for group in groups {
                tbody {
                  tr {
                    th(.init(name: "colspan", value: "4"), .scope(.rowgroup), .class("bg-base-200"))
                    { group.title }
                  }
                  for filter in group.filters {
                    Row(library: library, filter: filter, airflow: airflow, allowance: allowance)
                  }
                }
              }
            }
          }
        }
      } else {
        p { "Enter heating or cooling airflow in Equipment first." }
      }
    }
  }
  private struct Group {
    let title: String
    var filters: [AirFilter]
  }
  private var groups: [Group] {
    var result: [Group] = []
    for filter in library.filters where !library.favorites.contains(filter.id) {
      let title =
        filter.description.isEmpty
        ? filter.manufacturer : "\(filter.manufacturer) · \(filter.description)"
      if let index = result.firstIndex(where: { $0.title == title }) {
        result[index].filters.append(filter)
      } else {
        result.append(Group(title: title, filters: [filter]))
      }
    }
    return result
  }

  private func added(_ filter: AirFilter, _ airflow: Int) -> Double {
    filter.additionalPressureDrop(at: airflow, allowance: allowance)
  }
  private struct Row: HTML, Sendable {
    let library: FilterLibrary
    let filter: AirFilter
    let airflow: Int
    let allowance: Double?
    var body: some HTML<HTMLTag.tr> {

      let overCFM = airflow > filter.maxCFM
      let overDrop =
        library.maximumPressureDrop.map { filter.pressureDrop(at: airflow) > $0 + 1e-9 } ?? false
      return tr(
        .data("filter-over", value: String(overCFM || overDrop)),
        .data("filter-favorite", value: String(library.favorites.contains(filter.id)))
      ) {
        td { FilterFavoriteButton(library: library, filter: filter) }
        th(.scope(.row)) {
          span(.class("font-bold")) { filter.name }
          small(.class("block muted font-normal")) { filter.description }
          small(.class("block muted font-normal")) { "Up to \(filter.maxCFM.string()) CFM" }
        }
        td(.class("text-right tabular-nums")) {
          filterNumber(added(filter, airflow))
          if allowance != nil {
            small(.class("block muted")) {
              "\(filterNumber(filter.pressureDrop(at: airflow))) chart"
            }
          }
          if overCFM {
            div { span(.class("badge badge-warning badge-sm")) { "Over\u{00A0}max\u{00A0}CFM" } }
          } else if overDrop {
            div { span(.class("badge badge-ghost badge-sm")) { "Over limit" } }
          }
        }
        td { FilterUseButton(filter: filter, airflow: airflow, allowance: allowance, title: "Use") }
      }
    }
    private func added(_ filter: AirFilter, _ airflow: Int) -> Double {
      filter.additionalPressureDrop(at: airflow, allowance: allowance)
    }

  }

}

private struct FilterUseButton: HTML, Sendable {
  let filter: AirFilter
  let airflow: Int
  let allowance: Double?
  let title: String
  var body: some HTML<HTMLTag.button> {
    let value = filter.additionalPressureDrop(at: airflow, allowance: allowance)
    button(
      .type(.submit), .class("btn btn-sm btn-secondary"), .name("model"),
      .init(name: "value", value: filter.id),
      .init(
        name: "aria-label",
        value: "Use \(filter.name), \(filterNumber(value)) inches of water column"),
      .data("filter-covered", value: String(value == 0))
    ) { title }
    .attributes(.disabled, when: value > 1)
  }
}
