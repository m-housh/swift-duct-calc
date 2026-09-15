import Elementary
import Foundation
import ManualDCore
import Styleguide

struct FilterAccountView: HTML, Sendable {
  let library: FilterLibrary
  var query = FilterQuery()
  private var preferences: Bool { query.tab == "preferences" }
  private var shown: [AirFilter] {
    library.filters.filter { filter in
      (query.q.isEmpty
        || "\(filter.name) \(filter.description)".localizedCaseInsensitiveContains(query.q))
        && (query.scope == "all"
          || query.scope == "favorites" && library.favorites.contains(filter.id)
          || query.scope == "custom" && filter.source == nil
          || query.scope == "edited" && filter.isEdited)
    }.sorted { ($0.manufacturer, $0.model) < ($1.manufacturer, $1.model) }
  }
  var body: some HTML & Sendable {
    AccountPage(selected: preferences ? .preferences : .filters) {
      accountContent
    }
  }

  @HTMLBuilder private var accountContent: some HTML & Sendable {
    div(
      .id("filter-account"), .class("filter-account space-y-6"),
      .data("filter-revision", value: library.revision.uuidString)
    ) {
      PageTitleRow {
        PageTitle { preferences ? "Design preferences" : "Filter library" }
        button(
          .type(.button), .class("btn btn-primary"),
          .data("filter-editor", value: "/filters/editor")
        ) {
          SVG(.circlePlus)
          "Add filter"
        }
      }
      p(.class("account-intro")) {
        if preferences {
          "Choose the filters DuctCalc suggests for your projects."
        } else {
          "Pressure drop charts used when you add a filter to a project. Your account starts with Aprilaire and Dust Free charts. Edit or delete those entries, or add filters from any manufacturer."
        }
      }
      p(.id("filter-status"), .role("status"), .init(name: "aria-live", value: "polite")) {}
      if preferences { preferencesPanel } else { libraryPanel }
      restoreDialog
    }
    div(.id("filter-editor-mount")) {}
  }

  private var libraryPanel: some HTML & Sendable {
    section(
      .class("card border border-base-300 bg-base-100"),
      .init(name: "aria-labelledby", value: "library-title")
    ) {
      div(.class("card-body gap-4")) {
        div(.class("flex flex-wrap justify-between gap-3")) {
          h2(.id("library-title"), .class("card-title")) { "Filter library" }
          if !restoreCandidates.isEmpty {
            button(
              .type(.button), .class("btn btn-outline btn-sm"), .showModal(id: "restore-filters")
            ) { "Restore default filters" }
          }
        }
        p(.class("muted")) {
          "Changes apply to future lookups. Filter losses already saved in projects keep their values."
        }
        form(.action("/filters"), .method(.get), .class("filter-library-tools")) {
          label(.class("input")) {
            span(.class("sr-only")) { "Search filters" }
            input(
              .name("q"), .type(.search), .value(query.q),
              .placeholder("Manufacturer, model, or description"))
          }
          label {
            span(.class("sr-only")) { "Show filters" }
            select(.name("scope"), .class("select w-full")) {
              for (value, title) in [
                ("all", "All filters"), ("favorites", "Favorites"), ("custom", "Custom filters"),
                ("edited", "Edited defaults"),
              ] {
                option(.value(value)) { title }.attributes(.selected, when: query.scope == value)
              }
            }
          }
          label(.class("flex items-center gap-2")) {
            span { "Compare at" }
            input(
              .name("airflow"), .type(.number), .class("input w-28"), .min("1"), .max("100000"),
              .step("1"), .value(String(query.airflow)), .required)
            span { "CFM" }
          }
          button(.type(.submit), .class("btn btn-outline")) { "Update" }
        }
        if shown.isEmpty {
          p(.class("muted")) {
            library.filters.isEmpty
              ? "Your library is empty. Add a filter or restore the default filters."
              : "No filters match. Try another search or choose All filters."
          }
        }
        for brand in Array(Set(shown.map(\.manufacturer))).sorted() {
          div(
            .class("table-scroll"), .tabindex(0), .role("region"),
            .init(name: "aria-label", value: "\(brand) filters")
          ) {
            table(.class("table project-table")) {
              caption(.class("text-left font-bold text-base pb-2")) { brand }
              thead {
                tr {
                  th { span(.class("sr-only")) { "Favorite" } }
                  th { "Filter" }
                  th { "Chart airflow" }
                  th { "At \(query.airflow) CFM" }
                  th { span(.class("sr-only")) { "Actions" } }
                }
              }
              tbody {
                for filter in shown where filter.manufacturer == brand {
                  LibraryRow(library: library, query: query, filter: filter)
                }
              }
            }
          }
        }
      }
    }
  }

  private struct LibraryRow: HTML, Sendable {
    let library: FilterLibrary
    let query: FilterQuery
    let filter: AirFilter
    var body: some HTML<HTMLTag.tr> {

      tr {
        td { FilterFavoriteButton(library: library, filter: filter) }
        th(.scope(.row)) {
          span(.class("font-bold")) { filter.model }
          if filter.source == nil { span(.class("badge badge-ghost badge-sm")) { "Custom" } }
          if filter.isEdited { span(.class("badge badge-info badge-sm")) { "Edited" } }
          small(.class("block muted font-normal")) { filter.description }
        }
        td {
          "\(filter.points.first?.airflow ?? 0) to \(filter.maxCFM) CFM"
          small(.class("block muted")) { "\(filter.points.count) points" }
        }
        td(.class("tabular-nums")) {
          filterNumber(filter.pressureDrop(at: query.airflow))
          if query.airflow > filter.maxCFM {
            div { span(.class("badge badge-warning badge-sm")) { "Over max CFM" } }
          } else if let maximum = library.maximumPressureDrop,
            filter.pressureDrop(at: query.airflow) > maximum
          {
            small(.class("block muted")) { "Over pressure limit" }
          }
        }
        td {
          div(.class("row-actions")) {
            button(
              .type(.button), .class("btn btn-ghost"),
              .data("filter-editor", value: "/filters/editor?id=\(filter.id)"),
              .init(name: "aria-label", value: "Edit \(filter.name)")
            ) { SVG(.squarePen) }
            button(
              .type(.button), .class("btn btn-ghost"),
              .data("filter-editor", value: "/filters/editor?id=\(filter.id)&duplicate=true"),
              .init(name: "aria-label", value: "Duplicate \(filter.name)")
            ) { SVG(.copy) }
            button(
              .type(.button), .class("btn btn-ghost text-error"),
              .init(name: "aria-label", value: "Delete \(filter.name)"),
              .data(
                "filter-delete",
                value: filterJSON(
                  FilterLibrary.Change(action: .delete, revision: library.revision, id: filter.id))),
              .data("filter-name", value: filter.name)
            ) { SVG(.trash) }
          }
        }
      }
    }

  }

  private var preferencesPanel: some HTML & Sendable {
    section(.class("card border border-base-300 bg-base-100")) {
      div(.class("card-body gap-5")) {
        h2(.class("card-title")) { "Filter suggestions" }
        p(.class("muted")) {
          "DuctCalc suggests the first favorite below its airflow cutoff and within your pressure drop limit and the filter's maximum airflow. You can still choose any filter in the picker."
        }
        form(.data("filter-maximum", value: ""), .class("space-y-2")) {
          label(.class("grid gap-2")) {
            span(.class("font-semibold")) { "Maximum filter pressure drop" }
            span(.class("flex items-center gap-2")) {
              input(
                .name("maximumPressureDrop"), .type(.number), .class("input w-28"), .min("0.01"),
                .max("1"), .step("0.01"), .placeholder("None"),
                .value(library.maximumPressureDrop.map(filterNumber) ?? ""),
                .init(name: "aria-describedby", value: "filter-maximum-help"))
              span { "in. w.c." }
              button(.type(.submit), .class("btn btn-outline")) { "Save" }
            }
          }
          p(.id("filter-maximum-help"), .class("muted text-sm")) {
            "Leave blank for no pressure drop limit. Uses the full chart drop before any equipment filter allowance."
          }
        }
        h3(.class("font-semibold")) { "Favorite filters, in order" }
        p(.id("filter-cutoff-help"), .class("muted text-sm")) {
          "Suggest below is optional. At or above that CFM, DuctCalc tries the next favorite. Leave blank for no additional cutoff."
        }
        if library.favorites.isEmpty {
          p(.class("muted")) { "No favorites yet. Add one here or star a filter in your library." }
        }
        ol(.class("filter-preferences")) {
          for (index, filter) in library.preferredFilters.enumerated() {
            li {
              div(.class("grow")) {
                strong { filter.name }
                small(.class("block muted")) {
                  "\(filter.description) · up to \(filter.maxCFM) CFM"
                }
                form(
                  .data("filter-cutoff", value: filter.id), .class("filter-cutoff"),
                  .init(name: "aria-label", value: "Airflow preference for \(filter.name)")
                ) {
                  label(.for("filter-cutoff-\(filter.id)")) { "Suggest below" }
                  div(.class("flex items-center gap-2")) {
                    input(
                      .id("filter-cutoff-\(filter.id)"), .name("airflowCutoff"), .type(.number),
                      .class("input input-sm w-28"), .min("1"), .max("100000"), .step("1"),
                      .placeholder("None"),
                      .value(library.airflowCutoffs[filter.id].map(String.init) ?? ""),
                      .init(name: "aria-describedby", value: "filter-cutoff-help"))
                    span { "CFM" }
                    button(.type(.submit), .class("btn btn-outline btn-sm")) { "Save" }
                  }
                }
              }
              div(.class("filter-preference-actions")) {
                FilterAction(
                  library: library, action: .move, id: filter.id, direction: -1, title: "↑",
                  label: "Move \(filter.name) up", disabled: index == 0)
                FilterAction(
                  library: library, action: .move, id: filter.id, direction: 1, title: "↓",
                  label: "Move \(filter.name) down", disabled: index == library.favorites.count - 1)
                FilterAction(
                  library: library, action: .favorite, id: filter.id, selected: false, title: "×",
                  label: "Remove \(filter.name) from favorites")
              }
            }
          }
        }
        if library.filters.contains(where: { !library.favorites.contains($0.id) }) {
          form(.data("filter-add-favorite", value: ""), .class("flex gap-2")) {
            select(
              .name("id"), .class("select min-w-0 flex-1"),
              .init(name: "aria-label", value: "Filter to favorite")
            ) {
              for filter in library.filters where !library.favorites.contains(filter.id) {
                option(.value(filter.id)) { filter.name }
              }
            }
            button(.type(.submit), .class("btn btn-outline")) { "Add favorite" }
          }
        }
        div(.class("rounded-box bg-base-200 p-4 space-y-3")) {
          h3(.class("font-semibold")) { "Try your preferences" }
          form(.action("/filters"), .method(.get), .class("flex flex-wrap items-center gap-2")) {
            input(.type(.hidden), .name("tab"), .value("preferences"))
            label(.class("flex items-center gap-2")) {
              span { "Example airflow" }
              input(
                .name("airflow"), .type(.number), .class("input w-28"), .min("1"), .max("100000"),
                .step("1"), .value(String(query.airflow)), .required)
              span { "CFM" }
            }
            button(.type(.submit), .class("btn btn-outline")) { "Check" }
          }
          p(.class("muted text-sm")) { "This example does not change project airflow." }
          if let filter = library.suggestion(at: query.airflow) {
            p {
              "Suggests "
              strong { filter.name }
              " at \(filterNumber(filter.pressureDrop(at: query.airflow))) in. w.c."
            }
          } else {
            p {
              library.favorites.isEmpty
                ? "Add a favorite to get a suggestion."
                : "No favorite meets your pressure drop and airflow limits."
            }
          }
          for filter in library.preferredFilters {
            p(.class("text-sm")) {
              "\(filter.name): \(filterNumber(filter.pressureDrop(at: query.airflow))) in. w.c."
              if let reason = library.suggestionSkipReason(for: filter, at: query.airflow) {
                " · Skipped: \(reason)"
              } else {
                " · Within limits"
              }
            }
          }
        }
      }
    }
  }

  private var restoreCandidates: [AirFilter] {
    AirFilter.defaults.filter { original in
      guard let filter = library.filters.first(where: { $0.source == original.source }) else {
        return true
      }
      return filter.isEdited
    }
  }
  private var restoreDialog: some HTML & Sendable {
    ModalForm(id: "restore-filters", title: "Restore default filters", dismiss: true) {
      form(.data("filter-restore", value: ""), .class("space-y-4")) {
        p(.role("alert"), .data("filter-restore-error", value: "")) {}
        p { "Choose built-in filters to add or reset. Custom filters are kept." }
        for filter in restoreCandidates {
          label(.class("flex items-center gap-2")) {
            input(
              .type(.checkbox), .class("checkbox checkbox-sm"), .name("sources"),
              .value(filter.source!)
            )
            .attributes(
              .checked, when: !library.filters.contains(where: { $0.source == filter.source }))
            "\(filter.name)"
            small(.class("muted")) {
              library.filters.contains(where: { $0.source == filter.source })
                ? "Edited, resets values" : "Not in library"
            }
          }
        }
        button(.type(.submit), .class("btn btn-primary")) { "Restore selected" }
      }
    }
  }
}

struct FilterAction: HTML, Sendable {
  let library: FilterLibrary
  let action: FilterLibrary.Change.Action
  let id: String
  var selected: Bool? = nil
  var direction: Int? = nil
  let title: String
  let label: String
  var disabled = false
  var body: some HTML<HTMLTag.button> & Sendable {
    button(
      .type(.button), .class("btn btn-ghost btn-sm"), .init(name: "aria-label", value: label),
      .data(
        "filter-change",
        value: filterJSON(
          FilterLibrary.Change(
            action: action, revision: library.revision, id: id, selected: selected,
            direction: direction)))
    ) { title }
    .attributes(.disabled, when: disabled)
  }
}
struct FilterFavoriteButton: HTML, Sendable {
  let library: FilterLibrary
  let filter: AirFilter
  var body: some HTML<HTMLTag.button> & Sendable {
    let favorite = library.favorites.contains(filter.id)
    FilterAction(
      library: library, action: .favorite, id: filter.id, selected: !favorite,
      title: favorite ? "★" : "☆",
      label: "\(favorite ? "Remove" : "Add") \(filter.name) \(favorite ? "from" : "to") favorites"
    )
    .attributes(.init(name: "aria-pressed", value: String(favorite)), .class("filter-star"))
  }
}
