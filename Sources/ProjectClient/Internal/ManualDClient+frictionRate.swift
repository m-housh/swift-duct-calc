import DatabaseClient
import Dependencies
import ManualDClient
import ManualDCore

extension ManualDClient {

  func frictionRate(projectID: Project.ID) async throws -> ProjectClient.FrictionRateResponse {
    @Dependency(\.database) var database

        let componentLosses = try await database.componentLoss.fetch(projectID)
        let lengths = try await database.effectiveLength.fetchMax(projectID)

        let equipmentInfo = try await database.equipment.fetch(projectID)
        guard let staticPressure = equipmentInfo?.staticPressure else {
          return .init(componentLosses: componentLosses, equivalentLengths: lengths)
        }

        guard let totalEquivalentLength = lengths.total else {
          return .init(componentLosses: componentLosses, equivalentLengths: lengths)
        }

        return try await .init(
          componentLosses: componentLosses,
          equivalentLengths: lengths,
          frictionRate: frictionRate(
            .init(
              externalStaticPressure: staticPressure,
              componentPressureLosses: database.componentLoss.fetch(projectID),
              totalEffectiveLength: Int(totalEquivalentLength)
            )
          )
        )
  }
}
