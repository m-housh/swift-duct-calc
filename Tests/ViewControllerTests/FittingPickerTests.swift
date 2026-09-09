import Dependencies
import Elementary
import FileClient
import FittingClient
import Foundation
import Logging
import ManualDCore
import Testing

@testable import ViewController

struct FittingPickerTests {
  let client: FittingClient
  init() async throws {
    client = try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    } operation: {
      try await FittingClient.live()
    }
  }

  @Test func everyCatalogDefaultSurvivesFormTransport() async throws {
    for path in Fitting.PathType.allCases {
      for group in try await client.groups(path) {
        let definitions = try await client.fittings(.init(pathType: path, groupID: group.id))
        for definition in definitions {
          let inputs = try PickerFields.parse(
            definition, fields: PickerFields.defaults(definition.defaultInputs),
            definitions: definitions)
          #expect(inputs == definition.defaultInputs, "\(definition.id)")
        }
      }
    }
  }

  @Test func authoredDuctShapesReachEveryBrowserCard() async throws {
    for path in Fitting.PathType.allCases {
      for group in try await client.groups(path) {
        let definitions = try await client.fittings(.init(pathType: path, groupID: group.id))
        let rendered = await html(
          .group("{\"pathType\":\"\(path.rawValue)\",\"groupID\":\(group.id.rawValue)}"))
        let cards = rendered.components(separatedBy: "<article").dropFirst().map {
          String($0.prefix { $0 != ">" })
        }
        #expect(cards.count == definitions.count)
        for definition in definitions {
          let card = try #require(
            cards.first { $0.contains("data-catalog-id=\"\(definition.id.rawValue)\"") })
          #expect(card.contains("data-duct-shape=\"\(definition.ductShape.rawValue)\""))
        }
      }
    }
  }

  @Test func roundRadiusDefaultsAlsoReachPairsWithoutReplacingExplicitChoices() async throws {
    for id in ["8A-smooth", "8A-4-or-5-piece", "8A-3-piece"] {
      let fresh = await html(.configure(payload(id, group: 8)))
      #expect(fresh.contains("value=\"1.0\" selected"))
      let edited = await html(.configure(payload(id, group: 8, fields: ["radiusRatio": "0.75"])))
      #expect(edited.contains("value=\"0.75\" selected"))
      #expect(!edited.contains("value=\"1.0\" selected"))
      // Missing submitted inputs still require a choice; defaults initialize drafts only.
      let incomplete = await html(.evaluate(payload(id, group: 8, fields: ["angle": "90"])))
      #expect(!incomplete.contains("data-row="))
      for pair in ["8L-round", "8M-round"] {
        let base = await html(.configure(payload(pair, group: 8, fields: ["baseFitting": id])))
        #expect(base.contains("name=\"base.radiusRatio\""))
        #expect(base.contains("value=\"1.0\" selected"))
        let editedBase = await html(
          .configure(
            payload(pair, group: 8, fields: ["baseFitting": id, "base.radiusRatio": "1.5"])))
        #expect(editedBase.contains("value=\"1.5\" selected"))
        #expect(!editedBase.contains("value=\"1.0\" selected"))
      }
    }
  }

  @Test func defaultsAreOnlyAppliedWhenOpeningADraft() async throws {
    let config = await html(.configure(payload("8O", group: 8)))
    #expect(config.contains("value=\"mitered\" selected"))
    let missing = await html(.evaluate(payload("8O", group: 8)))
    #expect(!missing.contains("data-row="))
    #expect(missing.contains("Complete"))
    let evaluated = await html(
      .evaluate(payload("8O", group: 8, fields: ["insideCornerRadius": "mitered"])))
    #expect(evaluated.contains("data-row="))
  }

  @Test func flexUsesOneBoxVelocityAndRetainsIndependentBend() async throws {
    let config = await html(.configure(payload("11-junction-box", group: 11)))
    #expect(config.components(separatedBy: "name=\"flexVelocity\"").count == 2)
    #expect(config.contains("Velocity in flex duct"))
    #expect(!config.contains("Inlet velocity") && !config.contains("Outlet velocity"))
    let fields = [
      "flexVelocity": "700", "flexOpenings": "sidewall", "suppliedBend": "true",
      "bendVelocity": "900", "bendRadiusRatio": "one",
    ]
    let evaluated = await html(.evaluate(payload("11-junction-box", group: 11, fields: fields)))
    #expect(evaluated.contains("80 ft"))
    #expect(evaluated.contains("60 ft + 20 ft"))
    var unsupported = fields
    unsupported["flexOpenings"] = "topOrBottom"
    #expect(
      !(await html(.evaluate(payload("11-junction-box", group: 11, fields: unsupported)))).contains(
        "data-row="))
  }

  @Test func returnJunctionOffersSeparateContributions() async throws {
    let definition = try #require(
      try await client.fittings(.init(pathType: .return, groupID: .returnBranches)).first)
    let evaluated = await html(
      .evaluate(
        payload(
          definition.id.rawValue, group: 6, path: "return",
          fields: ["branchCFM": "200", "totalCFM": "1000"])))
    #expect(evaluated.contains("Add branch"))
    #expect(evaluated.contains("Add trunk"))
    #expect(evaluated.components(separatedBy: "data-row=").count == 3)
  }

  @Test func referenceKeepsSuppliedFractionalLengthAndCannotInjectHTML() async throws {
    let reference = pickerJSON(["pathType": "supply", "code": "4AG", "length": "61.375"])
    let result = await html(.reference(reference))
    #expect(result.contains("61.375"))
    #expect(result.contains("referenceEntry"))
    #expect(!result.contains("fittingID"))
    let invalid = await html(
      .reference(
        pickerJSON(["pathType": "supply", "code": "<script>alert(1)</script>", "length": "NaN"])))
    #expect(!invalid.contains("data-row=") && !invalid.contains("<script>"))
  }

  @Test func malformedAndWrongPathRequestsStayUnresolved() async throws {
    #expect(!(await html(.evaluate("{}"))).contains("data-row="))
    #expect(
      !(await html(.configure(String(repeating: "x", count: 65_537)))).contains("fp-config-form"))
    #expect(
      !(await html(.evaluate(payload("4AG", group: 4, path: "return")))).contains("data-row="))
    #expect(
      !(await html(.evaluate(payload("8O", group: 8, fields: ["insideCornerRadius": "invented"]))))
        .contains("data-row="))
  }

  private func payload(
    _ id: String, group: Int, path: String = "supply", fields: [String: String] = [:]
  ) -> String {
    let object: [String: Any] = [
      "pathType": path, "groupID": group, "fittingID": id, "fields": fields,
    ]
    return String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
  }

  private func html(_ route: SiteRoute.View.FittingPickerRoute) async -> String {
    await withDependencies {
      $0.fittingClient = client
    } operation: {
      let view = await route.renderView(
        on: .init(
          route: .fittings(route), isHtmxRequest: false, logger: .init(label: "picker-test")))
      return view.render()
    }
  }
}
