import Dependencies
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct PathTemplateViewTests {
  @Test func savedDefaults() {
    withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let templates = PathTemplate.defaultConfigurations().enumerated().map {
        index, configuration in
        PathTemplate(
          id: UUID(index + 100), userID: UUID(50), revision: UUID(index + 200),
          configuration: configuration, createdAt: Date(timeIntervalSince1970: 0),
          updatedAt: Date(timeIntervalSince1970: 0))
      }
      assertSnapshot(of: PathTemplatesView(templates: templates, projectID: UUID(10)), as: .html)
      assertSnapshot(
        of: PathTemplatesView(
          templates: templates, projectID: UUID(10), choosing: true, preferredType: .supply),
        as: .html)
    }
  }

  @Test func deletedDefaults() {
    assertSnapshot(of: PathTemplatesView(templates: [], projectID: UUID(10)), as: .html)
    assertSnapshot(
      of: PathTemplatesView(templates: [], projectID: UUID(10), choosing: true), as: .html)
  }
}
