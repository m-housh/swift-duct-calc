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
    let response = try await manualD.ductSize(88, 0.06)
    #expect(numberFormatter.string(for: response.calculatedSize) == "6.07")
    #expect(response.finalSize == 7)
    #expect(response.flexSize == 7)
    #expect(response.velocity == 329)
  }

  @Test(arguments: [
    (2400, 20, 22, 1101),
    (2800, 22, 24, 1061),
  ])
  func largeDuctSize(cfm: Int, finalSize: Int, flexSize: Int, velocity: Int) async throws {
    let response = try await manualD.ductSize(cfm: cfm, frictionRate: 0.1)
    #expect(response.finalSize == finalSize)
    #expect(response.flexSize == flexSize)
    #expect(response.velocity == velocity)
  }

  @Test
  func equivalentRectangularDuct() async throws {
    let response = try await manualD.rectangularSize(round: 7, height: 8)
    #expect(response.height == 8)
    #expect(response.width == 5)
  }
}
