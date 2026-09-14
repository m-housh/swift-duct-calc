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

extension PdfClientTests {
  @Test(arguments: ["mixed", "empty", "invalid"])
  func reportStates(state: String) async throws {
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = reportDate
    } operation: {
      let html = try await PdfClient.liveValue.html(
        reportFixture(empty: state == "empty", invalid: state == "invalid"))
      assertSnapshot(of: html, as: .html, named: state)
      let rendered = html.render()
      #expect(rendered.contains("Final round"))
      #expect(rendered.contains("images/brand/ductcalc-mark-dark.webp"))
      #expect(rendered.contains("Friction rate should be higher than 0.02") == (state == "invalid"))
    }
  }
}
