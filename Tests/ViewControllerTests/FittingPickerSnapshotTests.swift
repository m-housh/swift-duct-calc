import Dependencies
import Elementary
import FileClient
import FittingClient
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Styleguide
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct FittingPickerSnapshotTests {
  let client: FittingClient

  init() async throws {
    client = try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    } operation: {
      try await FittingClient.live()
    }
  }

  @Test func browser() async throws {
    // Keep both fixed and configurable cards without snapshotting the entire catalog.
    let view = try await withDependencies {
      $0.fittingClient = client
      $0.fittingClient.fittings = { request in
        try await client.fittings(request).filter {
          ["8A-mitered", "8O"].contains($0.id.rawValue)
        }
      }
    } operation: {
      try await SiteRoute.View.FittingPickerRoute.group(
        #"{"pathType":"supply","groupID":8}"#
      ).renderView(on: .test(.home))
    }
    assertSnapshot(of: view, as: .html)
  }

  @Test func fixedConfiguration() async {
    let view = await render(.configure(payload("4AG", group: .supplyBoots)))
    assertSnapshot(of: view, as: .html)
  }

  @Test func roundElbowConfiguration() async {
    let view = await render(
      .configure(payload("8A-smooth", fields: ["radiusRatio": "0.75"])))
    assertSnapshot(of: view, as: .html)
  }

  @Test func doubleElbowConfiguration() async {
    let view = await render(
      .configure(
        payload("8L-round", fields: ["baseFitting": "8A-smooth", "base.radiusRatio": "1.5"])))
    assertSnapshot(of: view, as: .html)
  }

  @Test func flexConfiguration() async {
    let view = await render(
      .configure(
        payload("11-junction-box", group: .flexJunctions, fields: ["suppliedBend": "true"])))
    assertSnapshot(of: view, as: .html)
  }

  @Test func calculatedResult() async {
    let view = await render(
      .evaluate(payload("8O", fields: ["insideCornerRadius": "mitered"])))
    assertSnapshot(of: view, as: .html)
  }

  @Test func incompleteResult() async {
    let view = await render(.evaluate(payload("8O")))
    assertSnapshot(of: view, as: .html)
  }

  @Test func returnJunctionResult() async {
    let view = await render(
      .evaluate(
        payload(
          "6A", group: .returnBranches, path: .return,
          fields: ["branchCFM": "200", "totalCFM": "1000"])))
    assertSnapshot(of: view, as: .html)
  }

  @Test func referenceResult() async {
    let view = await render(
      .reference(pickerJSON(["pathType": "supply", "code": "4AG", "length": "61.375"])))
    assertSnapshot(of: view, as: .html)
  }

  @Test func emptyPathEditor() {
    assertSnapshot(of: pathEditor(), as: .html)
  }

  @Test func referenceImportPreview() async throws {
    let payload =
      #"{"csv":"code,length_ft,quantity\n8a-SMOOTH,12.25,\n1a,35,2\n8A,6,1","pathType":"supply","entries":[],"straightFeet":25}"#
    let preview = try await withDependencies {
      $0.fittingClient = client
    } operation: {
      try await SiteRoute.View.FittingPickerRoute.importReferences(payload).previewReferenceImport(
        payload)
    }
    #expect(preview.issues.isEmpty)
    #expect(preview.rows.map { $0.entry.row.sourceCode } == ["8A", "1A", "8A"])
    #expect(preview.rows.map { $0.entry.quantity } == [1, 2, 1])
    #expect(
      preview.rows.allSatisfy { $0.entry.row.fittingID == nil && $0.entry.row.calculation == nil })
    #expect(preview.proposedTotal == 113.25)
    #expect(preview.repeatedGroups == [1])
    assertSnapshot(of: preview, as: .html)
  }

  @Test func referenceImportErrors() async {
    let view = await render(
      .importReferences(
        #"{"csv":"code,length_ft\n4ag,30.5\n5B,10\nunknown,20\n11-junction-box,50\n1A,-2","pathType":"supply","entries":[],"straightFeet":0}"#
      ))
    let html = view.render()
    #expect(html.contains("Line 3, code:"))
    #expect(html.contains("Line 4, code:"))
    #expect(html.contains("Line 5, code:"))
    #expect(html.contains("Line 6, length_ft:"))
    #expect(!html.contains("data-import-rows"))
    assertSnapshot(of: view, as: .html)
  }

  @Test func referenceImportCombinedDraftAndLimits() async throws {
    let entry = PathEditorRow(
      id: "existing", quantity: 1, savedIndex: 0,
      row: .init(
        name: "Reference entry", sourceCode: "1A", groupID: 1, origin: "referenceEntry", feet: 20))
    func preview(_ entries: [PathEditorRow], csv: String = "code,length_ft\n1A,10") async throws
      -> ReferenceImportPreview
    {
      let payload =
        "{\"csv\":\(pickerJSON(csv)),\"pathType\":\"supply\",\"entries\":\(pickerJSON(entries)),\"straightFeet\":25}"
      return try await withDependencies {
        $0.fittingClient = client
      } operation: {
        try await SiteRoute.View.FittingPickerRoute.importReferences(payload)
          .previewReferenceImport(payload)
      }
    }
    let combined = try await preview([entry])
    #expect(combined.proposedTotal == 55)
    #expect(combined.repeatedGroups == [1])
    #expect(combined.issues.isEmpty)
    let oversized = try await preview(Array(repeating: entry, count: 500))
    #expect(!oversized.issues.isEmpty)
    #expect(!oversized.render().contains("data-import-rows"))
    let overflow = try await preview([], csv: "code,length_ft\n1A,1e308\n1A,1e308")
    #expect(!overflow.issues.isEmpty)
    #expect(!overflow.render().contains("data-import-rows"))
  }

  @Test func populatedPathEditor() {
    let baseline = EquivalentLength(
      id: UUID(1), projectID: UUID(0), name: "Bedroom return", type: .return,
      straightLengths: [10, 25], groups: [],
      createdAt: .init(timeIntervalSince1970: 0), updatedAt: .init(timeIntervalSince1970: 0))
    let rows: [PathEditorRow] = [
      .init(
        id: "catalog-row", quantity: 2, savedIndex: 0,
        row: .init(
          name: "Smooth round radius elbow", sourceCode: "8A", groupID: 8,
          origin: "catalog", feet: 10, fittingID: "8A-smooth",
          artwork: "/images/fittings/group-8/8A-smooth.svg",
          fields: ["angle": "90", "radiusRatio": "1.5"],
          details: ["Angle: 90°", "Radius ratio: 1.5"])),
      .init(
        id: "reference-row", quantity: 1, savedIndex: 1,
        row: .init(
          name: "Reference entry", sourceCode: "6A", groupID: 6,
          origin: "referenceEntry", feet: 61.375)),
      .init(
        id: "legacy-row", quantity: 1, savedIndex: 2,
        row: .init(
          name: "Previously saved fitting", sourceCode: nil, groupID: 5,
          origin: "legacy", feet: 30)),
    ]
    assertSnapshot(of: pathEditor(baseline: baseline, rows: rows), as: .html)
    var duplicate = pathEditor(baseline: baseline, rows: rows)
    duplicate.duplicating = true
    #expect(duplicate.render().contains("id=\"path-name\" value=\"\" required"))
    #expect(duplicate.render().contains("data-duplicate=\"true\""))
    assertSnapshot(of: duplicate, as: .html, named: "duplicate")
  }

  private func pathEditor(baseline: EquivalentLength? = nil, rows: [PathEditorRow] = [])
    -> ProjectFittingPathView
  {
    ProjectFittingPathView(
      project: .init(
        id: UUID(0), name: "Sample house", streetAddress: "123 Main Street",
        city: "Monroe", state: "OH", zipCode: "45050",
        createdAt: .init(timeIntervalSince1970: 0), updatedAt: .init(timeIntervalSince1970: 0)),
      baseline: baseline, rows: rows, favorites: ["8A-smooth"],
      carousels: [
        (.supply, [.init(id: 4, title: "Supply boots and stack heads", image: nil, count: 1)]),
        (
          .return,
          [
            .init(
              id: 8, title: "Elbows and offsets", image: "/images/fittings/group-8/8A-smooth.svg",
              count: 2)
          ]
        ),
      ])
  }

  private func payload(
    _ id: String, group: Fitting.Group.ID = .elbows, path: Fitting.PathType = .supply,
    fields: [String: String] = [:]
  ) -> String {
    pickerJSONForSubmission(
      path: path, group: group, id: .init(rawValue: id), fields: fields)
  }

  private func render(_ route: SiteRoute.View.FittingPickerRoute) async -> AnySendableHTML {
    await withDependencies {
      $0.fittingClient = client
    } operation: {
      do { return try await route.renderView(on: .test(.fittings(route))) } catch {
        return ErrorMessage(
          ViewController.present(
            error, title: "Could not load fitting", reference: "test-reference"))
      }
    }
  }
}
