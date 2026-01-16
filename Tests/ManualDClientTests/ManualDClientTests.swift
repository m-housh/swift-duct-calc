import Dependencies
import DependenciesTestSupport
import Foundation
import ManualDClient
import ManualDCore
import Testing

@Suite(
  .dependencies {
    $0.manualD = ManualDClient.liveValue
  }
)
struct ManualDClientTests {

  @Dependency(\.manualD) var manualD

  var numberFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.roundingMode = .halfUp
    return formatter
  }

  @Test
  func ductSize() async throws {
    let response = try await manualD.ductSize(
      .init(designCFM: 88, frictionRate: 0.06)
    )
    #expect(numberFormatter.string(for: response.calculatedSize) == "6.07")
    #expect(response.finalSize == 7)
    #expect(response.flexSize == 7)
    #expect(response.velocity == 329)
  }

  @Test
  func frictionRate() async throws {
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
      _ = try await manualD.frictionRate(
        .init(
          externalStaticPressure: 0.5,
          componentPressureLosses: .mock,
          totalEffectiveLength: 0
        )
      )
    }
  }

  @Test
  func totalEffectiveLength() async throws {
    let response = try await manualD.totalEquivalentLength(
      .init(
        trunkLengths: [25],
        runoutLengths: [10],
        effectiveLengthGroups: [
          // NOTE: These are made up and may not correspond to actual manual-d group tel's.
          EffectiveLengthGroup(group: 1, letter: "a", effectiveLength: 20, category: .supply),
          EffectiveLengthGroup(group: 2, letter: "a", effectiveLength: 30, category: .supply),
          EffectiveLengthGroup(group: 3, letter: "a", effectiveLength: 10, category: .supply),
          EffectiveLengthGroup(group: 12, letter: "a", effectiveLength: 10, category: .supply),
        ]
      )
    )
    #expect(response == 105)
  }

  @Test
  func equivalentRectangularDuct() async throws {
    let response = try await manualD.rectangularSize(.init(round: 7, height: 8))
    #expect(response.height == 8)
    #expect(response.width == 5)
  }
}
