import Dependencies
import Elementary
import FittingClient
import Foundation
import ManualDCore

extension SiteRoute.View.FittingPickerRoute {
  func renderView(on request: ViewController.Request) async -> AnySendableHTML {
    @Dependency(\.fittingClient) var client
    do {
      switch self {
      case .review, .saveReview:
        return await renderCatalogReview(on: request)
      case .index:
        return await request.view {
          div(.class("p-8")) {
            h1 { "Fittings in your project" }
            a(.href("/projects"), .class("link")) {
              "Open a project and choose Equivalent Lengths to build a fitting path."
            }
          }
        }
      case .rows(let payload):
        let rows = try Self.decode([PathEditorRow].self, payload, limit: 2_000_000)
        guard rows.count <= 500 else { throw PickerError("Too many rows.") }
        return PathRowsView(rows: rows)
      case .group(let payload):
        let submission = try Self.decode(GroupBrowserSubmission.self, payload)
        let definitions = try await client.fittings(
          .init(pathType: submission.pathType, groupID: submission.groupID))
        var cards: [FittingBrowserCard] = []
        for definition in definitions {
          var artworks: [Fitting.Artwork] = []
          for view in definition.availableViews {
            if case .available(let art) = try await client.artwork(
              .init(fittingID: definition.id, view: view))
            {
              artworks.append(art)
            }
          }
          let submissionData = pickerJSONForSubmission(
            path: submission.pathType, group: submission.groupID, id: definition.id, fields: [:])
          let configuration = PickerConfiguration(
            submission: try Self.decode(Submission.self, submissionData), definition: definition,
            definitions: definitions, artworks: artworks)
          cards.append(
            .init(
              configuration: configuration,
              evaluation: try await client.evaluate(
                .init(
                  pathType: submission.pathType, fittingID: definition.id,
                  inputs: definition.defaultInputs))))
        }
        let title =
          try await client.groups(submission.pathType).first { $0.id == submission.groupID }?.title
          ?? "Fittings"
        return GroupBrowserView(title: title, cards: cards)
      case .configure(let payload), .evaluate(let payload):
        let submission = try Self.decode(Submission.self, payload)
        guard submission.fields.count <= 32,
          submission.fields.allSatisfy({ $0.key.count <= 64 && $0.value.count <= 256 })
        else { throw PickerError("Too many or oversized fields.") }
        let definitions = try await client.fittings(
          .init(pathType: submission.pathType, groupID: submission.groupID))
        guard let definition = definitions.first(where: { $0.id == submission.fittingID }) else {
          throw PickerError("This fitting is unavailable for the selected path.")
        }
        var artworks: [Fitting.Artwork] = []
        for view in definition.availableViews {
          if case .available(let art) = try await client.artwork(
            .init(fittingID: definition.id, view: view))
          {
            artworks.append(art)
          }
        }
        if case .configure = self {
          return PickerConfiguration(
            submission: submission, definition: definition, definitions: definitions,
            artworks: artworks)
        }
        let inputs = try PickerFields.parse(
          definition, fields: submission.fields, definitions: definitions)
        let evaluation = try await client.evaluate(
          .init(pathType: submission.pathType, fittingID: definition.id, inputs: inputs))
        let view =
          submission.fields["suppliedBend"] == "true"
          ? "supplied-bend" : submission.fields["artworkView"] ?? "individual"
        let art = artworks.first(where: { $0.view.rawValue == view }) ?? artworks.first
        return PickerResult(
          evaluation: evaluation, definition: definition, fields: submission.fields,
          artwork: art?.versionedPath)
      case .reference(let payload):
        let submission = try Self.decode(ReferenceSubmission.self, payload)
        guard submission.code.count <= 64, let length = Double(submission.length), length.isFinite,
          length > 0
        else { throw PickerError("Enter a code and a positive, finite equivalent length.") }
        switch try await client.resolveReference(
          .init(code: submission.code, pathType: submission.pathType))
        {
        case .recognized(let reference):
          return PickerAddButton(
            row: .init(
              name: "Reference entry", sourceCode: reference.code.rawValue,
              groupID: reference.groupID.rawValue, origin: "referenceEntry", feet: length),
            label: "Add entered \(pickerNumber(length)) ft")
        case .ineligible: throw PickerError("This code belongs to a different path type.")
        case .unknown:
          throw PickerError(
            "This code is not recognized by the catalog. Choose a fitting from the drawings.")
        }
      }
    } catch let error as PickerError {
      return p(.class("fp-error"), .init(name: "role", value: "alert")) { error.description }
    } catch {
      request.logger.error("Fitting picker: \(error)")
      return p(.class("fp-error"), .init(name: "role", value: "alert")) {
        "The fitting could not be loaded. Please try again."
      }
    }
  }

  static func decode<T: Decodable>(_ type: T.Type, _ payload: String, limit: Int = 65_536) throws
    -> T
  {
    guard payload.utf8.count <= limit, let data = payload.data(using: .utf8),
      let value = try? JSONDecoder().decode(type, from: data)
    else { throw PickerError("Invalid fitting request. Reopen the fitting and try again.") }
    return value
  }
}

struct PickerDraftRow: Codable, Sendable {
  var name: String
  var sourceCode: String?
  var groupID: Int
  var origin: String
  var feet: Double
  var fittingID: String? = nil
  var artwork: String? = nil
  var fields: [String: String]? = nil
  var calculation: Fitting.Calculation? = nil
  var returnJunction: Fitting.ReturnJunctionCalculation? = nil
  var column: String? = nil
  var details: [String] = []
}

struct PickerAddButton: HTML, Sendable {
  let row: PickerDraftRow
  var label = "Add fitting to path"
  var body: some HTML {
    button(.type(.button), .class("fp-primary"), .data("row", value: pickerJSON(row))) { label }
  }
}

struct PickerResult: HTML, Sendable {
  let evaluation: Fitting.Evaluation
  let definition: Fitting.Definition
  let fields: [String: String]
  let artwork: String?

  func row(
    _ feet: Double, calculation: Fitting.Calculation? = nil,
    junction: Fitting.ReturnJunctionCalculation? = nil, column: String? = nil
  ) -> PickerDraftRow {
    .init(
      name: definition.name, sourceCode: definition.sourceCode?.rawValue,
      groupID: definition.groupID.rawValue, origin: "catalog", feet: feet,
      fittingID: definition.id.rawValue, artwork: artwork, fields: fields, calculation: calculation,
      returnJunction: junction, column: column,
      details: pickerInputDetails(definition, fields: fields))
  }

  var body: some HTML {
    switch evaluation {
    case .unresolved(let issues):
      div(.class("fp-error"), .init(name: "role", value: "status")) {
        for issue in issues { p { pickerIssue(issue) } }
      }
    case .resolved(let calculation):
      div(.class("fp-result-summary")) {
        div {
          small { "EQUIVALENT LENGTH PER FITTING" }
          strong { "\(pickerNumber(calculation.equivalentLengthFeet)) ft" }
        }
        PickerAddButton(row: row(calculation.equivalentLengthFeet, calculation: calculation))
      }
      if let pressure = calculation.minimumUpstreamStaticPressureIWC {
        p(.class("fp-note")) {
          "Requires at least \(pickerNumber(pressure)) IWC upstream static pressure."
        }
      }
      if let selection = calculation.airflowSelection, selection.wasRounded {
        p(.class("fp-note")) {
          "\(pickerNumber(selection.submittedCFM)) CFM uses the published \(pickerNumber(selection.selectedCFM)) CFM row."
        }
      }
      if case .scaled(let base, let multiplier) = calculation.derivation {
        p(.class("fp-note")) {
          "Matching 90° elbows: \(pickerNumber(base.equivalentLengthFeet)) ft × \(pickerNumber(multiplier)). This is the complete pair length."
        }
      }
      if calculation.components.count > 1 {
        p(.class("fp-note")) {
          "Included contributions: \(calculation.components.map { pickerNumber($0.equivalentLengthFeet) + " ft" }.joined(separator: " + "))."
        }
      }
    case .resolvedReturnJunction(let calculation):
      p(.class("fp-note")) {
        "Choose the contribution for this path. Branch and trunk are separate paths."
      }
      p {
        "CFM1/CFM2 = \(pickerNumber(calculation.ratioSelection.calculatedRatio)); published ratio \(pickerNumber(calculation.ratioSelection.selectedRatio)) (\(calculation.ratioSelection.reason.rawValue))."
      }
      div(.class("fp-result-summary")) {
        PickerAddButton(
          row: row(
            calculation.branch.equivalentLengthFeet, junction: calculation, column: "branch"),
          label: "Add branch · \(pickerNumber(calculation.branch.equivalentLengthFeet)) ft")
        if let trunk = calculation.trunk {
          PickerAddButton(
            row: row(trunk.equivalentLengthFeet, junction: calculation, column: "trunk"),
            label: "Add trunk · \(pickerNumber(trunk.equivalentLengthFeet)) ft")
        } else {
          p { "Trunk: unavailable for this source row." }
        }
      }
    }
  }
}

func pickerNumber(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...12)))
}

func pickerIssue(_ issue: Fitting.Issue) -> String {
  let field: String
  switch issue.field {
  case .heightInches: field = "height"
  case .widthInches: field = "width"
  case .radiusInches: field = "inside radius"
  case .downstreamBranches, .plenumReturns: field = "count"
  case .junctionPath: field = "route through junction"
  case .branchCFM: field = "branch airflow"
  case .totalCFM: field = "combined airflow"
  case .airflowCFM: field = "airflow"
  case .baseFitting, .baseInputs: field = "matching 90° elbow construction and its inputs"
  case .flexOpenings: field = "entrance or exits (only sidewall openings are supported)"
  case .flexVelocity: field = "velocity in flex duct"
  case .bendVelocity: field = "bend velocity"
  case .bendRadiusRatio: field = "bend R/D"
  default: field = "fitting inputs"
  }
  switch issue.code {
  case .missingInput: return "Complete the \(field)."
  case .branchExceedsTotal: return "Branch airflow cannot exceed combined downstream airflow."
  case .unsupportedRatio:
    return
      "The \(field) do not match a supported source ratio. Check the published ratios beside the inputs."
  case .unsupportedAirflow: return "Enter airflow within the supported source range shown above."
  case .unsupportedCombination:
    return "This combination is not supported by the source table. Check the \(field)."
  case .nonfiniteInput, .nonpositiveDimension, .nonpositiveAirflow, .nonpositiveReturnCount:
    return "Enter a positive, finite value for the \(field)."
  case .negativeBranchCount: return "The branch count cannot be negative."
  default: return "Check the \(field); this selection cannot be calculated."
  }
}

func pickerJSONForSubmission(
  path: Fitting.PathType, group: Fitting.Group.ID, id: Fitting.ID, fields: [String: String]
) -> String {
  struct Value: Encodable {
    let pathType: Fitting.PathType
    let groupID: Fitting.Group.ID
    let fittingID: Fitting.ID
    let fields: [String: String]
  }
  return pickerJSON(Value(pathType: path, groupID: group, fittingID: id, fields: fields))
}

func pickerInputDetails(_ definition: Fitting.Definition, fields: [String: String]) -> [String] {
  if case .doubleElbow = definition.inputRequirement {
    return fields["baseFitting"].map { ["Matching 90° elbow construction: " + $0] } ?? []
  }
  return PickerFields.fields(definition.inputRequirement).compactMap { field in
    guard let value = fields[field.name], !value.isEmpty else { return nil }
    if ["bendVelocity", "bendRadiusRatio"].contains(field.name), fields["suppliedBend"] != "true" {
      return nil
    }
    let label =
      field.choices?.first(where: { $0.0 == value })?.1
      ?? (value == "true" ? "Yes" : value == "false" ? "No" : value)
    return "\(field.label): \(label)"
  }
}
