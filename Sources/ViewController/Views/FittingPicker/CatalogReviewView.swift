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
      p(.id("review-status"), .init(name: "role", value: "status")) {}
      div(.class("review-grid")) {
        for entry in entries {
          article(.class("review-card"), .data("review-id", value: entry.id.rawValue)) {
            a(.href(entry.artwork.versionedPath), .target("_blank"), .rel("noopener")) {
              img(
                .src(entry.artwork.versionedPath), .alt(entry.artwork.altText),
                .init(name: "loading", value: "lazy"))
            }
            div(.class("review-card-controls")) {
              h3 { "\(entry.sourceCode?.rawValue ?? "Group 11") · \(entry.name)" }
              small { entry.id.rawValue }
              label {
                "Prefer for duct shape"
                select(.name("ductShape"), .class("select select-bordered")) {
                  for shape in Fitting.Shape.allCases {
                    option(.value(shape.rawValue)) { shape.reviewLabel }.attributes(
                      .selected, when: shape == entry.ductShape)
                  }
                }
              }
              label(.class("review-checkbox")) {
                input(.type(.checkbox), .name("reviewed"), .class("checkbox")).attributes(
                  .checked, when: entry.reviewed)
                "I have reviewed this classification"
              }
              p(.class("review-card-status")) { entry.reviewed ? "Reviewed" : "Needs review" }
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
