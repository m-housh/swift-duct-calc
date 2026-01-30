import DatabaseClient
import Dependencies
import ManualDClient
import ManualDCore

extension ManualDClient {

  func frictionRate(details: Project.Detail) async throws -> ProjectClient.FrictionRateResponse {

    let maxContainer = details.maxContainer
    guard let totalEquivalentLength = maxContainer.totalEquivalentLength else {
      return .init(componentLosses: details.componentLosses, equivalentLengths: maxContainer)
    }

    return try await .init(
      componentLosses: details.componentLosses,
      equivalentLengths: maxContainer,
      frictionRate: frictionRate(
        .init(
          externalStaticPressure: details.equipmentInfo.staticPressure,
          componentPressureLosses: details.componentLosses,
          totalEquivalentLength: Int(totalEquivalentLength)
        )
      )
    )
  }

  func frictionRate(projectID: Project.ID) async throws -> ProjectClient.FrictionRateResponse {
    @Dependency(\.database) var database

    let componentLosses = try await database.componentLosses.fetch(projectID)
    let lengths = try await database.equivalentLengths.fetchMax(projectID)

    let equipmentInfo = try await database.equipment.fetch(projectID)
    guard let staticPressure = equipmentInfo?.staticPressure else {
      return .init(componentLosses: componentLosses, equivalentLengths: lengths)
    }

    guard let totalEquivalentLength = lengths.totalEquivalentLength else {
      return .init(componentLosses: componentLosses, equivalentLengths: lengths)
    }

    return try await .init(
      componentLosses: componentLosses,
      equivalentLengths: lengths,
      frictionRate: frictionRate(
        .init(
          externalStaticPressure: staticPressure,
          componentPressureLosses: componentLosses,
          totalEquivalentLength: Int(totalEquivalentLength)
        )
      )
    )
  }
}
