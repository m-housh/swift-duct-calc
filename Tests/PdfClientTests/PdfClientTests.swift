import Dependencies
import Foundation
import HTMLSnapshotTesting
import PdfClient
import SnapshotTesting
import Testing

@Suite(.snapshots(record: .missing))
struct PdfClientTests {

  @Test
  func html() async throws {

    try await withDependencies {
      $0.pdfClient = .liveValue
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    } operation: {
      @Dependency(\.pdfClient) var pdfClient

      let html = try await pdfClient.html(.mock())
      assertSnapshot(of: html, as: .html)
    }

  }
}
