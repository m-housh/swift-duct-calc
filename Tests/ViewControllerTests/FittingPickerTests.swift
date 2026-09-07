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

  @Test func preferenceUsesGroupTwoTrunkShapeWithoutRestrictingCatalog() async throws {
    let expected = [
      (1, "1A", "round"), (1, "1D", "rectangular"),
      (2, "2A", "rectangular"), (2, "2K", "rectangular"),
      (2, "2N", "round"), (2, "2Q", "round"), (4, "4A", "rectangular"),
      (8, "8A-easy-bend", "oval"), (12, "12W", "schematic"),
    ]
    for (group, id, shapes) in expected {
      let groupID = try #require(Fitting.Group.ID(rawValue: group))
      let definition = try #require(
        try await client.fittings(.init(pathType: .supply, groupID: groupID))
          .first { $0.id.rawValue == id })
      #expect(definition.pickerDuctShape.rawValue == shapes)
    }
    let rendered = await html(.group("{\"pathType\":\"supply\",\"groupID\":2}"))
    #expect(rendered.contains("data-catalog-id=\"2A\""))
    #expect(rendered.contains("data-catalog-id=\"2N\""))
    #expect(rendered.contains("data-duct-shape=\"round\""))
    #expect(rendered.contains("data-duct-shape=\"rectangular\""))
  }

  @Test func everySupplyBootUsesItsAuditedDuctConnection() async throws {
    let round: Set<String> = [
      "4G", "4H", "4I", "4J", "4K", "4L", "4Q", "4R", "4S", "4T", "4U", "4V",
      "4W", "4X", "4Y", "4Z", "4AA", "4AB", "4AC", "4AD", "4AE", "4AG", "4AJ", "4AK",
    ]
    let rectangular: Set<String> = [
      "4A", "4B", "4C", "4D", "4E", "4F", "4M", "4N", "4O", "4P", "4AF", "4AH",
      "4AI", "4AL", "4AM", "4AN", "4AO", "4AP", "4AQ", "4AR",
    ]
    let definitions = try await client.fittings(.init(pathType: .supply, groupID: .supplyBoots))
    // A new catalog entry must be audited instead of silently inheriting "mixed".
    #expect(Set(definitions.map { $0.id.rawValue }) == round.union(rectangular))
    #expect(
      Set(definitions.filter { $0.pickerDuctShape == .round }.map { $0.id.rawValue }) == round)
    #expect(
      Set(definitions.filter { $0.pickerDuctShape == .rectangular }.map { $0.id.rawValue })
        == rectangular)
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
