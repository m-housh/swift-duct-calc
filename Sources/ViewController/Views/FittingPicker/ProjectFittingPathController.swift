import DatabaseClient
import Dependencies
import Elementary
import FittingClient
import Foundation
import ManualDCore
import ProjectClient
import Styleguide

struct PathEditorSubmission: Decodable {
  let baseline: EquivalentLength?
  let name: String
  let pathType: Fitting.PathType
  let straightLengths: [Int]
  let entries: [PathEditorRow]
}
struct FavoriteSubmission: Decodable {
  let fittingID: Fitting.ID
  let selected: Bool
}
struct GroupBrowserSubmission: Decodable {
  let pathType: Fitting.PathType
  let groupID: Fitting.Group.ID
}

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute {
  func renderPathEditor(on request: ViewController.Request, projectID: Project.ID) async
    -> AnySendableHTML
  {
    @Dependency(\.database) var database
    @Dependency(\.fittingClient) var client
    @Dependency(\.projectClient) var projectClient
    do {
      let user = try request.currentUser()
      guard let project = try await database.projects.getForUser(projectID, user.id) else {
        throw PickerError("Project not found.")
      }
      switch self {
      case .editor(let id):
        var saved: EquivalentLength?
        if let id {
          guard let path = try await database.equivalentLengths.get(id), path.projectID == projectID
          else { throw PickerError("Path not found.") }
          saved = path
        }
        var rows: [PathEditorRow] = []
        for (index, group) in (saved?.groups ?? []).enumerated() {
          let metadata = group.fitting
          let calculation = metadata?.calculation
          let junction = metadata?.returnJunction
          let fittingID = calculation?.fittingID ?? junction?.fittingID
          var art: Fitting.Artwork?
          let fields = (calculation?.inputs ?? junction?.inputs).map(PickerFields.defaults) ?? [:]
          if let fittingID,
            case .available(let image) = try await client.artwork(
              .init(
                fittingID: fittingID,
                view: fields["suppliedBend"] == "true" ? .suppliedBend : .individual))
          {
            art = image
          }
          var details: [String] = []
          if let fittingID, let groupID = Fitting.Group.ID(rawValue: group.group),
            let pathType = saved?.type,
            let definition = try await client.fittings(.init(pathType: pathType, groupID: groupID))
              .first(where: { $0.id == fittingID })
          {
            details = pickerInputDetails(definition, fields: fields)
          }
          rows.append(
            .init(
              id: metadata?.id.uuidString ?? "saved-\(index)", quantity: group.quantity,
              savedIndex: index,
              row: .init(
                name: metadata?.name ?? "Saved reference entry",
                sourceCode: group.letter.isEmpty ? nil : "\(group.group)\(group.letter)",
                groupID: group.group, origin: metadata?.origin.rawValue ?? "legacy",
                feet: group.value, fittingID: fittingID?.rawValue, artwork: art?.versionedPath,
                fields: fields, calculation: calculation, returnJunction: junction,
                column: metadata?.column?.rawValue, details: details)))
        }
        var carousels: [(Fitting.PathType, [GroupCarousel.Item])] = []
        for path in Fitting.PathType.allCases {
          var items: [GroupCarousel.Item] = []
          for group in try await client.groups(path) {
            var image: String?
            if let id = group.representativeFittingID,
              case .available(let art) = try await client.artwork(.init(fittingID: id))
            {
              image = art.versionedPath
            }
            items.append(
              .init(
                id: group.id.rawValue, title: group.title, image: image,
                count: group.availableFittingCount))
          }
          carousels.append((path, items))
        }
        let page = ProjectFittingPathView(
          project: project, baseline: saved, rows: rows,
          favorites: try await database.fittingFavorites.fetch(user.id), carousels: carousels)
        return await request.view { page }
      case .savePath(let payload):
        guard payload.utf8.count <= 2_000_000, let data = payload.data(using: .utf8),
          let submission = try? JSONDecoder().decode(PathEditorSubmission.self, from: data)
        else { throw PickerError("Invalid path submission.") }
        guard submission.entries.count <= 500 else {
          throw PickerError("A path can contain up to 500 rows.")
        }
        var entries: [Fitting.PathEntry] = []
        var definitions: [Fitting.Definition] = []
        for group in try await client.groups(submission.pathType) {
          definitions += try await client.fittings(
            .init(pathType: submission.pathType, groupID: group.id))
        }
        for entry in submission.entries {
          if let savedIndex = entry.savedIndex {
            entries.append(.saved(index: savedIndex, quantity: entry.quantity))
            continue
          }
          let row = entry.row
          if row.origin == "referenceEntry" {
            entries.append(
              .reference(
                code: row.sourceCode ?? "", feet: row.feet, quantity: entry.quantity,
                replacing: entry.replacesIndex))
          } else if row.origin == "catalog",
            let definition = definitions.first(where: { $0.id.rawValue == row.fittingID })
          {
            let inputs = try PickerFields.parse(
              definition, fields: row.fields ?? [:], definitions: definitions)
            entries.append(
              .catalog(
                id: definition.id, inputs: inputs,
                column: row.column.flatMap(Fitting.Column.init(rawValue:)),
                quantity: entry.quantity, replacing: entry.replacesIndex))
          } else {
            throw PickerError(
              "A new row must be calculated or entered from a reference. Previously saved rows must identify their original entry."
            )
          }
        }
        let saved = try await projectClient.saveFittingPath(
          user.id, projectID,
          .init(
            baseline: submission.baseline, name: submission.name, pathType: submission.pathType,
            straightLengths: submission.straightLengths, entries: entries))
        return div(.data("saved-path", value: saved.id.uuidString)) { "Path saved." }
      case .favorite(let payload):
        let submission = try SiteRoute.View.FittingPickerRoute.decode(
          FavoriteSubmission.self, payload)
        guard case .available = try await client.artwork(.init(fittingID: submission.fittingID))
        else { throw PickerError("Fitting not found.") }
        try await database.fittingFavorites.set(user.id, submission.fittingID, submission.selected)
        return span(.data("favorite-saved", value: "true")) { "Favorite updated." }
      default: throw PickerError("Unknown path operation.")
      }
    } catch let error as PickerError {
      return p(.class("fp-error"), .init(name: "role", value: "alert")) { error.description }
    } catch let error as FittingPathError {
      return p(.class("fp-error"), .init(name: "role", value: "alert")) { error.description }
    } catch {
      request.logger.error("Fitting path: \(error)")
      return p(.class("fp-error"), .init(name: "role", value: "alert")) {
        "The path could not be saved or loaded. Your draft has been kept. Please try again."
      }
    }
  }
}

struct FittingBrowserCard: HTML, Sendable {
  let configuration: PickerConfiguration
  let evaluation: Fitting.Evaluation
  var definition: Fitting.Definition { configuration.definition }
  var body: some HTML {
    article(
      .class("art-card guided-input-card"), .data("catalog-id", value: definition.id.rawValue),
      .data("search", value: "\(definition.sourceCode?.rawValue ?? "Group 11") \(definition.name)"),
      .data("fixed", value: definition.inputRequirement == .fixed ? "true" : "false")
    ) {
      button(
        .type(.button), .class("favorite-button"), .data("favorite", value: definition.id.rawValue),
        .init(name: "aria-pressed", value: "false"),
        .init(
          name: "aria-label",
          value: "Favorite \(definition.sourceCode?.rawValue ?? definition.name)")
      ) { "☆ Favorite" }
      configuration
      template(.class("initial-result")) {
        PickerResult(
          evaluation: evaluation, definition: definition,
          fields: PickerFields.defaults(definition.defaultInputs),
          artwork: configuration.artworks.first?.versionedPath)
      }
    }
  }
}

struct GroupBrowserView: HTML, Sendable {
  let title: String
  let cards: [FittingBrowserCard]
  var body: some HTML {
    div(.class("toolbar")) {
      h2 { title }
      label {
        "Find a fitting"
        input(.type(.search), .id("catalog-search"), .placeholder("Code, description, shape…"))
      }
    }
    p(.class("muted")) {
      "Favorites first · Select a fixed fitting to add it directly. Other fittings need the inputs shown on the card."
    }
    div(.class("grid fitting-grid")) { for card in cards { card } }
    p(.id("catalog-empty"), .hidden) { "No matching fittings in this group." }
  }
}
