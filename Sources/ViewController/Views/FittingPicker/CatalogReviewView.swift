import Dependencies
import Elementary
import FittingClient
import Foundation
import ManualDCore
import Styleguide

extension SiteRoute.View.FittingPickerRoute {
  func renderCatalogReview(on request: ViewController.Request) async -> AnySendableHTML {
    @Dependency(\.fittingClient) var client
    do {
      _ = try request.currentUser()
      switch self {
      case .review(let number):
        guard let group = Fitting.Group.ID(rawValue: number) else {
          throw PickerError("Unknown fitting group.")
        }
        let catalog = try await client.catalogReview()
        return await request.view { CatalogReviewView(catalog: catalog, group: group) }
      case .saveReview(let payload):
        guard payload.utf8.count <= 65_536, let data = payload.data(using: .utf8) else {
          throw PickerError("Invalid review submission.")
        }
        let submission = try JSONDecoder().decode(Fitting.CatalogReviewSave.self, from: data)
        let saved = try await client.saveCatalogReview(submission)
        return div(.data("review-saved", value: saved.version)) {
          "Saved to catalog.json. Newly opened picker groups use these classifications."
        }
      default: throw CatalogReviewError.disabled
      }
    } catch {
      request.logger.error("Catalog review: \(error)")
      return div(.class("p-6"), .init(name: "role", value: "alert")) {
        if let error = error as? CatalogReviewError {
          error.description
        } else if let error = error as? PickerError {
          error.description
        } else {
          "The catalog review could not be loaded or saved. Your selections are still on this page. Check the server log and try again."
        }
      }
    }
  }
}

struct CatalogReviewView: HTML, Sendable {
  let catalog: Fitting.CatalogReview
  let group: Fitting.Group.ID
  var entries: [Fitting.CatalogReviewEntry] { catalog.entries.filter { $0.groupID == group } }
  var body: some HTML {
    link(.rel(.stylesheet), .href("/css/catalog-review.css"))
    script(.src("/js/catalog-review.js"), .defer) {}
    div(
      .id("catalog-review"), .class("catalog-review"), .data("version", value: catalog.version),
      .data("group", value: String(group.rawValue))
    ) {
      header {
        a(.href("/projects"), .class("link")) { "← Projects" }
        h1 { "Review fitting duct shapes" }
        p {
          "Choose the duct shape that should bring each fitting to the top of the picker. Use the duct connection, not the register face or the fitting name."
        }
        p(.class("review-note")) {
          "Development catalog editor · Save writes to the source catalog.json shared by this server. Changes take effect in newly opened picker groups and can be reviewed and committed through Git."
        }
      }
      nav(.class("review-groups"), .init(name: "aria-label", value: "Fitting groups")) {
        for id in Fitting.Group.ID.allCases {
          let items = catalog.entries.filter { $0.groupID == id }
          a(
            .href("/fittings/review?group=\(id.rawValue)"), .class("btn btn-sm"),
            .data("review-group", value: String(id.rawValue))
          ) {
            "Group \(id.rawValue) · \(items.filter(\.reviewed).count)/\(items.count)"
          }.attributes(.class("btn-primary"), when: group == id)
        }
      }
      div(.class("review-save-bar")) {
        div(.class("review-save-heading")) {
          div {
            h2 { "Group \(group.rawValue) · \(entries.first?.groupTitle ?? "Fittings")" }
            p(.id("review-progress")) {
              "\(entries.filter(\.reviewed).count) of \(entries.count) reviewed"
            }
          }
          button(.id("save-catalog-review"), .type(.button), .class("btn btn-primary"), .disabled) {
            "Save review"
          }
        }
        div(
          .class("review-bulk"), .init(name: "role", value: "group"),
          .init(name: "aria-label", value: "Bulk review actions")
        ) {
          span(.id("review-selection-count"), .init(name: "role", value: "status")) { "0 selected" }
          select(
            .id("review-bulk-shape"), .class("select select-bordered select-sm"),
            .init(name: "aria-label", value: "Duct shape for selected rows")
          ) {
            option(.value("")) { "Choose duct shape…" }
            for shape in Fitting.Shape.allCases {
              option(.value(shape.rawValue)) { shape.reviewLabel }
            }
          }
          button(.id("review-apply-shape"), .type(.button), .class("btn btn-sm"), .disabled) {
            "Apply shape"
          }
          button(.id("review-mark-reviewed"), .type(.button), .class("btn btn-sm"), .disabled) {
            "Mark reviewed"
          }
          button(.id("review-mark-pending"), .type(.button), .class("btn btn-sm"), .disabled) {
            "Mark pending"
          }
          button(
            .id("review-clear-selection"), .type(.button), .class("btn btn-sm btn-ghost"), .disabled
          ) { "Clear selection" }
        }
        p(.class("review-note review-selection-help")) {
          "Select rows or Shift-click a range. Applying a shape also marks the selected rows reviewed. Save review writes all unsaved changes in this group."
        }
      }
      p(.id("review-status"), .init(name: "role", value: "status")) {}
      div(
        .class("review-table-scroll"), .init(name: "tabindex", value: "0"),
        .init(name: "role", value: "region"),
        .init(name: "aria-label", value: "Fitting classifications")
      ) {
        table(.class("review-table")) {
          thead {
            tr {
              th(.init(name: "scope", value: "col")) {
                input(
                  .id("review-select-all"), .type(.checkbox), .class("checkbox checkbox-sm"),
                  .init(name: "aria-label", value: "Select all fittings in this group"))
              }
              th(.init(name: "scope", value: "col")) { "Drawing" }
              th(.init(name: "scope", value: "col")) { "Fitting" }
              th(.init(name: "scope", value: "col")) { "Prefer for duct shape" }
              th(.init(name: "scope", value: "col")) { "Reviewed" }
              th(.init(name: "scope", value: "col")) { "Status" }
            }
          }
          tbody {
            for entry in entries {
              let code = entry.sourceCode?.rawValue ?? "Group 11"
              tr(.data("review-id", value: entry.id.rawValue)) {
                td {
                  input(
                    .type(.checkbox), .name("selected"), .class("checkbox checkbox-sm"),
                    .init(name: "aria-label", value: "Select \(code)"))
                }
                td(.class("review-drawing")) {
                  a(
                    .href(entry.artwork.versionedPath), .target("_blank"), .rel("noopener"),
                    .init(name: "aria-label", value: "Open \(code) drawing at full size")
                  ) {
                    img(
                      .src(entry.artwork.versionedPath), .alt(entry.artwork.altText),
                      .init(name: "loading", value: "lazy"))
                  }
                }
                th(.init(name: "scope", value: "row"), .class("review-fitting")) {
                  strong { code }
                  span { entry.name }
                }
                td {
                  select(
                    .name("ductShape"), .class("select select-bordered select-sm"),
                    .init(name: "aria-label", value: "Duct shape for \(code)")
                  ) {
                    for shape in Fitting.Shape.allCases {
                      option(.value(shape.rawValue)) { shape.reviewLabel }.attributes(
                        .selected, when: shape == entry.ductShape)
                    }
                  }
                }
                td(.class("review-confirm")) {
                  input(
                    .type(.checkbox), .name("reviewed"), .class("checkbox checkbox-sm"),
                    .init(name: "aria-label", value: "Reviewed \(code)")
                  ).attributes(.checked, when: entry.reviewed)
                }
                td(.class("review-card-status")) { entry.reviewed ? "Reviewed" : "Needs review" }
              }
            }
          }
        }
      }
    }
  }
}

extension Fitting.Shape {
  var reviewLabel: String {
    switch self {
    case .round: "Round"
    case .rectangular: "Rectangular"
    case .oval: "Oval"
    case .mixed: "Mixed / transition"
    case .schematic: "Shape-independent"
    }
  }
}
