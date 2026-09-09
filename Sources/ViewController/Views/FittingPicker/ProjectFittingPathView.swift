import Elementary
import Foundation
import ManualDCore
import Styleguide

struct ProjectFittingPathView: HTML, Sendable {
  let project: Project
  let baseline: EquivalentLength?
  let rows: [PathEditorRow]
  let favorites: [Fitting.ID]
  var catalogReviewEnabled: Bool = false
  let carousels: [(Fitting.PathType, [GroupCarousel.Item])]
  var root: String { "/projects/\(project.id)/effective-lengths" }
  var body: some HTML {
    link(.rel(.stylesheet), .href("/css/fitting-path.css?v=app-theme-1"))
    link(.rel(.stylesheet), .href("/css/picker-preference.css"))
    link(.rel(.stylesheet), .href("/css/fitting-favorites.css"))
    link(.rel(.stylesheet), .href("/css/fitting-path-modal.css?v=2"))
    script(.src("/js/group-carousel.js"), .defer) {}
    script(.src("/js/path-templates.js?v=path-revisions-3"), .defer) {}
    script(.src("/js/template-modal.js?v=template-modal-2"), .defer) {}
    script(.src("/js/fitting-path.js?v=template-modal-2"), .defer) {}
    EditorDialog(id: "fitting-path", titleID: "path-title") {
      section(.class("path-sheet")) {
        header {
          div {
            p(.class("muted")) { "\(project.name) · Equivalent Lengths" }
            h1(.id("path-title")) { "Fittings in this path" }
            p(.class("muted")) { "Build and review your path, one fitting at a time." }
          }
          button(.type(.button), .id("close-path")) { "Cancel" }
        }
        div(.class("path-fields")) {
          label {
            "Path name"
            input(
              .id("path-name"), .value(baseline?.name ?? ""), .required,
              .init(name: "maxlength", value: "200"))
          }
          label {
            "Path type"
            select(.id("path-type")) {
              for path in Fitting.PathType.allCases.reversed() {
                option(.value(path.rawValue)) { path.rawValue.capitalized }.attributes(
                  .selected, when: path == (baseline?.type ?? .supply))
              }
            }
          }
          label {
            "Straight duct lengths (ft)"
            input(
              .id("path-straight"),
              .value(baseline?.straightLengths.map(String.init).joined(separator: ", ") ?? ""),
              .placeholder("10, 25, 15"))
            small { "Separate whole-foot runs with commas; leave empty for no straight duct." }
          }
        }
        section(.class("coverage")) {
          div(.class("flex w-full flex-wrap items-center justify-between gap-2")) {
            small { "Groups in this path" }
            if baseline == nil {
              button(
                .type(.button),
                .id("path-from-template"), .class("link-button template-action"),
                .data("template-url", value: guidedPathURL(project.id))
              ) {
                "From template"
              }
            }
          }
          div(.id("group-coverage")) {}
        }
        section(.class("path-table"), .init(name: "aria-label", value: "Fitting path entries")) {
          div(.class("sheet-columns"), .init(name: "aria-hidden", value: "true")) {
            for text in ["#", "Drawing", "Fitting / group", "EL each", "Quantity", "Subtotal", ""] {
              span { text }
            }
          }
          div(.id("path-rows")) { PathRowsView(rows: rows) }
          button(.type(.button), .class("add-row"), .data("open-picker", value: "true")) {
            span(.init(name: "aria-hidden", value: "true")) { "+" }
            "Add fitting"
          }
        }
        div(.class("path-entry-actions")) {
          button(.type(.button), .id("quick-entry-open")) { "Quick reference entry" }
          a(
            .id("path-fitting-reference"),
            .href(route: .fittingReference(.init(system: (baseline?.type ?? .supply).rawValue))),
            .target("_blank"), .rel("noopener"), .class("link-button")
          ) { "Open fitting reference ↗" }
        }
        footer(.class("sheet-total")) {
          div(.class("fitting-total")) {
            small { "Fittings total" }
            strong(.id("fittings-total")) { "0 ft" }
          }
          div(.class("total-context")) {
            div {
              small { "Straight duct" }
              strong(.id("straight-total")) { "0 ft" }
            }
            div {
              small { "Total equivalent length" }
              strong(.id("path-total")) { "0 ft" }
            }
          }
          button(.type(.button), .class("primary"), .id("save-path")) { "Save path" }
        }
        p(.id("path-status"), .init(name: "role", value: "status")) {}
      }
      PickerDialog(id: "picker-dialog", title: "Choose a fitting") {
        div(.class("toolbar")) {
          button(.type(.button), .id("choose-groups")) { "1 · Choose group" }
          span { "2 · Choose fitting" }
        }
        SegmentedControl(
          name: "shape-preference", title: "Prefer",
          options: [
            .init(value: "none", label: "No preference"),
            .init(value: "round", label: "Round"),
            .init(value: "rectangular", label: "Rectangular"),
          ], selected: "none")
        p(.class("muted picker-preference-help")) {
          "Preferred duct shape first. Starring a fitting keeps it in place and adds a copy to Favorites. Remembered in this browser."
        }
        if catalogReviewEnabled {
          a(.href("/fittings/review"), .target("_blank"), .rel("noopener")) {
            "Review catalog duct shapes ↗"
          }
        }
        div(.id("group-selectors")) {
          for (path, items) in carousels {
            div(.data("path-carousel", value: path.rawValue)) { GroupCarousel(items: items) }
          }
        }
        div(.id("fitting-browser"), .hidden) {}
        p(.id("picker-status"), .init(name: "role", value: "status")) {}
      }
      PickerDialog(id: "edit-dialog", title: "Edit fitting") { div(.id("edit-fitting")) {} }
      PickerDialog(id: "reference-dialog", title: "Quick reference entry") {
        p {
          "Enter the code and equivalent length from your reference. Your supplied length is preserved."
        }
        form(.id("reference-form")) {
          label {
            "Fitting code"
            input(.name("code"), .required, .placeholder("4AG"))
          }
          label {
            "Equivalent length per fitting (ft)"
            input(.name("length"), .type(.number), .step("any"), .min("0.000001"), .required)
          }
          button(.type(.submit), .class("primary")) { "Check entry" }
        }
        div(.id("reference-result"), .init(name: "aria-live", value: "polite")) {}
      }
    }
    .attributes(
      .class("fitting-path"), .data("endpoint", value: root),
      .data("baseline", value: pickerJSON(baseline)), .data("rows", value: pickerJSON(rows)),
      .data("favorites", value: pickerJSON(favorites)))
  }
}

/// Browser transport is not trusted for saving; the save controller produces typed domain requests.
struct PathEditorRow: Codable, Sendable {
  var id: String
  var quantity: Int
  var replacesIndex: Int? = nil
  var savedIndex: Int?
  var row: PickerDraftRow
}

struct PathRowsView: HTML, Sendable {
  let rows: [PathEditorRow]
  var body: some HTML {
    if rows.isEmpty {
      div(.class("sheet-empty")) {
        h3 { "Start with your first fitting" }
        p { "Choose a drawing or enter a value from your reference." }
      }
    }
    for (index, entry) in rows.enumerated() {
      let row = entry.row
      article(.class("path-row sheet-row"), .data("row-id", value: entry.id)) {
        span(.class("row-number")) { "\(index + 1)" }
        if let art = row.artwork, art.hasPrefix("/images/fittings/") {
          img(.src(art), .alt(row.name), .class("sheet-art"))
        } else {
          div(.class("sheet-art")) { span { row.sourceCode ?? "Group \(row.groupID)" } }
        }
        div(.class("sheet-description")) {
          strong(.class("code")) { row.sourceCode ?? "Group \(row.groupID)" }
          h3 { row.name }
          p(.class("sheet-group")) { "Group \(row.groupID)" }
          small {
            row.origin == "catalog"
              ? "Calculated\(row.column.map { " · " + $0 } ?? "")"
              : row.origin == "legacy" ? "Previously saved value" : "Entered from reference"
          }
          if !row.details.isEmpty {
            details {
              summary { "Selected inputs" }
              for text in row.details { p { text } }
            }
          }
          if let pressure = row.calculation?.minimumUpstreamStaticPressureIWC {
            small { "Requires ≥ \(pickerNumber(pressure)) IWC upstream static pressure." }
          }
        }
        span(.class("sheet-unit")) { "\(pickerNumber(row.feet)) ft" }
        label(.class("row-quantity-label")) {
          span(.class("visually-hidden")) { "Quantity for \(row.sourceCode ?? row.name)" }
          input(
            .type(.number), .min("1"), .max("1000000"), .step("1"), .value(String(entry.quantity)),
            .data("quantity", value: entry.id))
        }
        strong(.class("sheet-subtotal")) { "\(pickerNumber(row.feet * Double(entry.quantity))) ft" }
        div(.class("sheet-actions")) {
          button(.type(.button), .data("edit-row", value: entry.id)) { "Edit" }
          button(.type(.button), .data("remove-row", value: entry.id)) { "Remove" }
        }
      }
    }
  }
}
