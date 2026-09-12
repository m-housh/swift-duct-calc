import ManualDClient
import ManualDCore
import Testing

struct InvalidFrictionRateTests {
  @Test func sharedValidationDistinguishesInvalidDesigns() {
    for rate in [-0.018, 0, 0.02, 0.18, Double.infinity, Double.nan] {
      #expect(FrictionRate(availableStaticPressure: 0.2, value: rate).hasErrors)
    }
    #expect(!FrictionRate(availableStaticPressure: 0.2, value: 0.1).hasErrors)
    #expect(
      FrictionRate(availableStaticPressure: -0.07, value: -0.018).error?.reason.contains(
        "meet or exceed") == true)
  }
  @Test func invalidArithmeticCannotReachDuctSizing() async {
    for rate in [-0.018, 0, Double.infinity, Double.nan] {
      await #expect(throws: (any Error).self) {
        try await ManualDClient.liveValue.ductSize(cfm: 100, frictionRate: rate)
      }
    }
  }
}
