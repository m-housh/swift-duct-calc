import Dependencies
import FileClient
import FittingClient
import Foundation
import Testing

struct FittingLiveTests {
  @Test func readsOnceThroughFileClientAndRetainsLoadedCatalog() async throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try Data(
      contentsOf: root.appendingPathComponent("Sources/FittingClient/Resources/catalog.json"))
    var document = try #require(JSONSerialization.jsonObject(with: source) as? [String: Any])
    document["revision"] = "injected-test-catalog"
    let fixture = try JSONSerialization.data(withJSONObject: document)
    let reads = Reads()
    let client = try await withDependencies {
      $0.fileClient.readFile = { path in
        await reads.append(path)
        return fixture
      }
    } operation: {
      try await FittingClient.live()
    }

    // Using the client outside its construction scope must not read the file again.
    _ = try await client.groups(.supply)
    _ = try await client.fittings(.init(pathType: .supply, groupID: .supplyBoots))
    _ = try await client.artwork(.init(fittingID: "4A"))
    _ = try await client.resolveReference(.init(code: "4A", pathType: .supply))
    let result = try await client.evaluate(
      .init(pathType: .supply, fittingID: "4A", inputs: .fixed))
    guard case .resolved(let calculation) = result else {
      Issue.record("Expected the injected catalog to produce a calculation")
      return
    }
    #expect(calculation.catalogRevision == "injected-test-catalog")
    let paths = await reads.paths
    #expect(paths.count == 1)
    let path = try #require(paths.first)
    #expect(path.hasPrefix("/"))
    #expect(URL(fileURLWithPath: path).lastPathComponent == "catalog.json")
  }

  @Test func readFailureThrowsDuringConstruction() async {
    await withDependencies {
      $0.fileClient.readFile = { _ in throw ReadError.unavailable }
    } operation: {
      await #expect(throws: ReadError.unavailable) {
        try await FittingClient.live()
      }
    }
  }

  @Test func decodeFailureThrowsDuringConstruction() async {
    await withDependencies {
      $0.fileClient.readFile = { _ in Data("not JSON".utf8) }
    } operation: {
      await #expect(throws: FittingClientError.self) {
        try await FittingClient.live()
      }
    }
  }

  private actor Reads {
    var paths: [String] = []

    func append(_ path: String) {
      paths.append(path)
    }
  }

  private enum ReadError: Error {
    case unavailable
  }
}

/// Exercise the live factory and its real resource path with a test file reader.
func loadBundledFittingClient() async throws -> FittingClient {
  try await withDependencies {
    $0.fileClient.readFile = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
  } operation: {
    try await FittingClient.live()
  }
}
