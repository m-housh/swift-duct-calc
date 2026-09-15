import ManualDClient
import ManualDCore

extension ManualDClient {

  public func frictionRate(details: Project.Detail) async throws -> FrictionRate? {

    let maxContainer = details.maxContainer
    guard !details.componentLosses.isEmpty, let equipment = details.equipmentInfo,
      let totalEquivalentLength = maxContainer.totalEquivalentLength
    else {
      return nil
    }

    return try await frictionRate(
      .init(
        externalStaticPressure: equipment.staticPressure,
        componentPressureLosses: details.componentLosses,
        totalEquivalentLength: Int(totalEquivalentLength)
      )
    )
  }
}
