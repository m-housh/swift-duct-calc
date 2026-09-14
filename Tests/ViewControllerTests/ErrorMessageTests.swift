import DatabaseClient
import Foundation
import HTMLSnapshotTesting
import ManualDClient
import ManualDCore
import SnapshotTesting
import Styleguide
import Testing
import ViewController

@Suite(.snapshots(record: .failed))
struct ErrorMessageTests {
  @Test func storedDataDecodingFailuresHaveDiagnosticReferences() {
    let error = DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "private stored data"))
    let failure = ViewController.present(
      error, title: "Could not open page", reference: "test-reference")
    #expect(failure.status == 500)
    #expect(failure.reference == "test-reference")
    #expect(!failure.message.contains("private stored data"))
  }

  @Test func validationSummary() {
    assertSnapshot(
      of: ErrorMessage(
        .init(
          title: "Could not save equipment", message: "Check the following values and try again.",
          fields: [
            .init(
              "staticPressure",
              "External static pressure must be greater than 0 and less than 1 in. w.c.")
          ]
        )), as: .html)
  }

  @Test func expiredSession() {
    assertSnapshot(
      of: ErrorMessage(
        .init(
          title: "Could not save room",
          message:
            "Your session has ended. Sign in in another tab, then return here and try again.",
          status: 401, actions: [.init("Sign in in another tab", href: "/login")]
        )), as: .html)
  }

  @Test func validationDescriptionSurvivesErrorErasure() {
    let error: any Error = ValidationError("Choose a valid register and a positive height.")
    #expect(error.localizedDescription == "Choose a valid register and a positive height.")
  }

  @Test func calculationDescriptionSurvivesErrorErasure() async throws {
    do {
      _ = try await ManualDClient.liveValue.ductSize(cfm: 0, frictionRate: 0.1)
      Issue.record("Invalid airflow should fail")
    } catch {
      #expect(error.localizedDescription == "Design CFM should be greater than 0.")
    }
  }
}
