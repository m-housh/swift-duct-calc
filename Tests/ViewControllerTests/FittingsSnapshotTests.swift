import Dependencies
import FittingClient
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct FittingsSnapshotTests {
  let catalog: FittingReference

  init() async throws {
    let client = try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    } operation: {
      try await FittingClient.live()
    }
    catalog = try client.reference()
  }

  @Test func allGroupsGuest() throws {
    let page = try FittingReferencePage(
      catalog: catalog, query: .init(group: "all", q: "8a smooth"), isLoggedIn: false)
    assertSnapshot(of: FittingsView(page: page), as: .html)
  }

  @Test func returnGroupSignedIn() throws {
    let page = try FittingReferencePage(
      catalog: catalog, query: .init(system: "return", group: "8", q: "8a smooth"),
      isLoggedIn: true)
    assertSnapshot(of: FittingsView(page: page), as: .html)
  }

  @Test func emptySupplyGroup() throws {
    let page = try FittingReferencePage(
      catalog: catalog, query: .init(system: "supply", group: "1", q: "no-such-fitting"),
      isLoggedIn: false)
    assertSnapshot(of: FittingsView(page: page), as: .html)
  }
}
