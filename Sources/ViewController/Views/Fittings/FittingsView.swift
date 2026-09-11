import Elementary
import FittingClient
import Foundation
import ManualDCore
import Styleguide

struct FittingsView: HTML, Sendable {
  let page: FittingReferencePage

  var body: some HTML {
    Navbar(
      showFittingsButton: false, isLoggedIn: page.isLoggedIn,
      shortcutsDialogID: FittingsShortcutsDialog.id, showProjectsShortcut: false)
    FittingsShortcutsDialog(isLoggedIn: page.isLoggedIn)
    div(
      .id("fittings-page"), .data("tools", value: page.isLoggedIn ? "enabled" : "disabled"),
      .data("url", value: page.path())
    ) {
      a(.class("skip"), .href("#workspace")) { "Skip to fittings" }
      section(.class("intro")) {
        div {
          h1 { "Fitting reference" }
          p { "Drawings, reference values, and conditions for your duct path." }
        }
        div(.class("catalog-stat")) {
          strong {
            String(page.catalog.entries.filter { !$0.isConcept }.count)
            span { " + \(page.catalog.entries.filter(\.isConcept).count)" }
          }
          span { "approved drawings + concept" }
        }
      }
      toolbar
      div(.class("mobile-group-navigation")) {}
      div(.id("workspace"), .tabindex(-1)) {
        div(.class("explorer combined")) {
          groupNavigation
          fittingList
          combinedPanel
        }
      }
      footer(.class("reference-footer")) {
        span { "Reference values · calculation rules remain under review." }
      }
      dialog(.id("copy-dialog"), .custom(name: "aria-labelledby", value: "copy-title")) {
        h2(.id("copy-title")) { "Copy reference data" }
        p { "Automatic copying is unavailable. Select and copy the text below." }
        textarea(
          .custom(name: "aria-label", value: "Text to copy"), .custom(name: "readonly", value: "")
        ) {}
        button(.data("action", value: "close-copy")) { "Done" }
      }
      div(.class("reference-toast"), .id("toast"), .role("status")) {}
    }
  }

  private var toolbar: some HTML {
    form(.class("toolbar"), .role("search"), .id("filters"), .action("/fittings"), .method(.get)) {
      div(
        .class("system-toggle"), .role("group"),
        .custom(name: "aria-label", value: "Filter fitting groups by air path")
      ) {
        for system in ["all", "supply", "return"] {
          a(
            .href(page.path(["system": system])), .data("reference-nav", value: ""),
            .data("system", value: system),
            .custom(name: "aria-current", value: String(page.system == system))
          ) { system.capitalized }
        }
      }
      input(.type(.hidden), .name("system"), .value(page.system))
      input(.type(.hidden), .name("fitting"), .value(page.selected?.id ?? ""))
      if page.showData {
        input(.type(.hidden), .name("data"), .value(page.format))
        input(.type(.hidden), .name("scope"), .value(page.scope))
      }
      label(.class("search")) {
        span(.custom(name: "aria-hidden", value: "true")) { "⌕" }
        input(
          .id("search"), .name("q"), .type(.search), .value(page.search),
          .placeholder("Search \(page.system) groups by ID, name, or shape…"),
          .custom(name: "aria-label", value: "Search \(page.system) groups by ID, name, or shape"),
          .custom(name: "aria-keyshortcuts", value: "Control+K"),
          .custom(name: "autocomplete", value: "off"))
        kbd { "Ctrl+K" }
      }
      label(.class("select-label group-control")) {
        span { "Fitting group" }
        select(
          .id("group-filter"), .name("group"), .custom(name: "form", value: "filters"),
          .custom(name: "aria-label", value: "Fitting group")
        ) {
          option(.value("all")) { page.allGroupsLabel }.attributes(
            .selected, when: page.group == "all")
          for group in page.groups {
            option(.value(String(group.id))) { "\(group.id) · \(group.name)" }
              .attributes(.selected, when: page.group == String(group.id))
          }
        }
      }
      label(.class("select-label")) {
        "Values"
        select(.id("value-filter"), .name("type")) {
          for (value, title) in [
            ("all", "All reference types"), ("fixed", "Fixed reference"),
            ("conditional", "Requires conditions"),
          ] {
            option(.value(value)) { title }.attributes(.selected, when: page.type == value)
          }
        }
      }
      button(.type(.submit), .class("text-button")) { "Search" }
      a(
        .href("/fittings?group=all"), .class("text-button"), .data("reference-nav", value: ""),
        .data("action", value: "reset")
      ) { "Reset" }
      span(.id("result-count"), .class("result-count"), .custom(name: "aria-live", value: "polite"))
      { "\(page.rows.count) fittings" }
    }
  }

  private var groupNavigation: some HTML {
    aside(.class("group-sidebar"), .custom(name: "aria-label", value: "Fitting groups")) {
      div(.class("group-sidebar-header")) {}
      div(.class("panel-caption")) {
        page.system == "all" ? "GROUPS" : "\(page.system.uppercased()) GROUPS"
        span { String(page.groups.count) }
      }
      FittingReferenceGroupLink(page: page, id: "all", name: page.allGroupsLabel)
      for group in page.groups {
        FittingReferenceGroupLink(page: page, id: String(group.id), name: group.name)
      }
      div(.class("sidebar-note")) { "Group 11 uses a concept drawing." }
    }
  }

  private var fittingList: some HTML {
    aside(.class("fitting-sidebar"), .custom(name: "aria-label", value: "Fittings")) {
      div(.class("panel-caption")) {
        "FITTINGS"
        span { String(page.rows.count) }
      }
      for entry in page.rows {
        a(
          .class("fitting-item \(entry.id == page.selected?.id ? "active" : "")"),
          .href(page.path(["fitting": entry.id])), .data("reference-nav", value: ""),
          .data("select", value: entry.id)
        ) {
          FittingReferenceDrawing(entry: entry)
          span {
            strong { entry.record.source_fitting_code }
            span { entry.record.name }
            small {
              entry.record.variant != .null
                ? entry.record.variant.text
                : entry.record.shape != .null
                  ? entry.record.shape.text : "Group \(entry.record.group)"
            }
          }
          span(.class("item-arrow"), .custom(name: "aria-hidden", value: "true")) { "›" }
        }.attributes(
          .custom(name: "aria-current", value: "true"), when: entry.id == page.selected?.id)
      }
      if page.rows.isEmpty { p(.class("sidebar-note")) { "No matching drawings." } }
    }
  }

  private var combinedPanel: some HTML {
    section(
      .class("combined-panel"), .custom(name: "aria-label", value: "Fitting reference and data")
    ) {
      div(.class("combined-toolbar")) {
        div {
          strong { "Fitting details" }
          code { page.selected?.id ?? "" }
        }
        if page.isLoggedIn {
          if page.selected != nil {
            a(
              .href(page.path(["data": page.showData ? "" : page.format])),
              .data("reference-nav", value: ""), .data("action", value: "toggle-data"),
              .custom(name: "aria-expanded", value: String(page.showData)),
              .custom(name: "aria-controls", value: "combined-data")
            ) {
              span { "{ }" }
              page.showData ? "Hide data" : "Show CSV / JSON"
            }
          }
        } else {
          a(.class("sign-in-data"), .href(page.loginPath), .data("login", value: "")) {
            "Sign in for CSV / JSON"
          }
        }
      }
      div(.class("combined-content \(page.hasData ? "with-data" : "")")) {
        div(.class("detail-panel")) {
          if let entry = page.selected {
            FittingReferenceDetail(entry: entry, page: page)
          } else {
            div(.class("empty")) {
              span(.class("empty-symbol")) { "⌕" }
              h2 { "No matching fittings" }
              p { "Try a shorter name, another group, or a fitting ID such as 8A." }
              a(.href("/fittings?group=all"), .data("reference-nav", value: ""), .class("button")) {
                "Show all fittings"
              }
            }
          }
        }
        div(.id("combined-data")) {
          if page.hasData { dataPanel }
        }.attributes(.hidden, when: !page.hasData)
      }
    }
  }

  private var dataPanel: some HTML {
    section(.class("code-panel")) {
      div(.class("code-heading")) {
        div(.class("format-tabs"), .custom(name: "aria-label", value: "Data format")) {
          for (format, title) in [("json", "JSON"), ("csv", "CSV"), ("path", "Path example")] {
            a(
              .href(page.path(["data": format])), .data("reference-nav", value: ""),
              .data("format", value: format),
              .custom(name: "aria-current", value: String(page.format == format))
            ) { title }
          }
        }
        button(.class("browser-only"), .data("action", value: "copy-data")) { "Copy" }
        a(
          .href(page.path(["download": "1"])), .data("action", value: "download-data"),
          .custom(name: "download", value: page.filename)
        ) { "Download ↓" }
      }
      div(.class("code-subhead")) {
        form(.id("export-scope"), .action("/fittings"), .method(.get)) {
          input(.type(.hidden), .name("system"), .value(page.system))
          input(.type(.hidden), .name("group"), .value(page.group))
          input(.type(.hidden), .name("fitting"), .value(page.selected?.id ?? ""))
          input(.type(.hidden), .name("q"), .value(page.search))
          input(.type(.hidden), .name("type"), .value(page.type))
          input(.type(.hidden), .name("data"), .value(page.format))
          label {
            "Include"
            select(.id("scope"), .name("scope")) {
              option(.value("record")) { "Selected fitting" }.attributes(
                .selected, when: page.scope == "record")
              option(.value("filtered")) { "All \(page.rows.count) filtered fittings" }.attributes(
                .selected, when: page.scope == "filtered")
            }.attributes(.disabled, when: page.format == "path")
            button(.type(.submit), .class("scope-submit")) { "Apply" }
          }
        }
        span { page.format == "path" ? "ILLUSTRATIVE SCHEMA" : "REFERENCE DATA" }
      }
      pre(
        .tabindex(0),
        .custom(name: "aria-label", value: "\(page.format.uppercased()) reference data")
      ) { code { page.exportText } }
      div(.class("code-note")) {
        strong {
          page.format == "csv"
            ? "One row per drawing variant."
            : page.format == "path"
              ? "A possible shape for a future path entry."
              : "Stable IDs. Explicit source conditions."
        }
        p {
          page.format == "csv"
            ? "Nested conditions and tables are quoted JSON fields, so conditional values are preserved."
            : page.format == "path"
              ? "This example uses the selected fitting. Null values need source conditions; this page does not submit or import paths."
              : "These reference records use an experimental schema."
        }
      }
    }
  }
}

private enum ReferenceImageTag: HTMLTrait.Paired { static let name = "image" }
struct FittingReferenceDrawing: HTML, Sendable {
  let entry: FittingReference.Entry
  var body: some HTML {
    if let viewport = entry.viewport {
      svg(
        .class("drawing"),
        .custom(
          name: "viewBox",
          value: viewport.map { FittingReference.Value.number($0).text }.joined(separator: " ")),
        .role("img"),
        .custom(
          name: "aria-label", value: "\(entry.record.source_fitting_code) · \(entry.record.name)")
      ) {
        HTMLElement<ReferenceImageTag, EmptyHTML>(
          .custom(name: "href", value: entry.imagePath), .custom(name: "width", value: "640"),
          .custom(name: "height", value: "520")
        ) {}
      }
    } else {
      img(
        .class("drawing"), .src(entry.imagePath),
        .alt("\(entry.record.source_fitting_code) · \(entry.record.name)"),
        .custom(name: "loading", value: "lazy"), .custom(name: "decoding", value: "async"))
    }
  }
}

private struct FittingReferenceGroupLink: HTML, Sendable {
  let page: FittingReferencePage
  let id: String
  let name: String
  private var shortcut: String? {
    switch id {
    case "1", "2", "3", "4", "5", "6", "7", "8", "9": id
    case "10": "0"
    default: nil
    }
  }

  var body: some HTML {
    a(
      .class("group-item \(page.group == id ? "active" : "")"), .href(page.path(["group": id])),
      .data("reference-nav", value: ""), .data("group", value: id)
    ) {
      span(.class("group-number")) { id == "all" ? "∑" : String(format: "%02d", Int(id) ?? 0) }
      span { name }
      small {
        String(
          page.catalog.filter(group: id, query: page.search, type: page.type, system: page.system)
            .count)
      }
    }
    .attributes(.custom(name: "aria-current", value: "true"), when: page.group == id)
    .attributes(
      .custom(name: "aria-keyshortcuts", value: "Control+Alt+\(shortcut ?? "")"),
      .title("Group \(id): \(name), Ctrl+Alt+\(shortcut ?? "")"), when: shortcut != nil)
  }

}
