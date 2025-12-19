import Dependencies
import Foundation
import ManualDClient
import ManualDCore
import Testing

@Suite("ManualDClient Tests")
struct ManualDClientTests {

  var numberFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.roundingMode = .halfUp
    return formatter
  }

  @Test
  func frictionRate() async throws {
    let manualD = ManualDClient.liveValue
    let response = try await manualD.frictionRate(
      .init(
        externalStaticPressure: 0.5,
        componentPressureLosses: .mock,
        totalEffectiveLength: 185
      )
    )
    #expect(numberFormatter.string(for: response.availableStaticPressure) == "0.11")
    #expect(numberFormatter.string(for: response.frictionRate) == "0.06")
  }

  @Test
  func frictionRateFails() async throws {
    await #expect(throws: ManualDError.self) {
      let manualD = ManualDClient.liveValue
      _ = try await manualD.frictionRate(
        .init(
          externalStaticPressure: 0.5,
          componentPressureLosses: .mock,
          totalEffectiveLength: 0
        )
      )
    }
  }
}
