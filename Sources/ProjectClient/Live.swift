import DatabaseClient
import Dependencies
import Logging
import ManualDClient
import ManualDCore

extension ProjectClient: DependencyKey {

  public static var liveValue: Self {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD

    return .init(
      calculateDuctSizes: { projectID in
        try await database.calculateDuctSizes(projectID: projectID)
      },
      calculateRoomDuctSizes: { projectID in
        try await database.calculateRoomDuctSizes(projectID: projectID)
      },
      calculateTrunkDuctSizes: { projectID in
        try await database.calculateTrunkDuctSizes(projectID: projectID)
      },
      createProject: { userID, request in
        let project = try await database.projects.create(userID, request)
        try await database.componentLoss.createDefaults(projectID: project.id)
        return try await .init(
          projectID: project.id,
          rooms: database.rooms.fetch(project.id),
          sensibleHeatRatio: database.projects.getSensibleHeatRatio(project.id),
          completedSteps: database.projects.getCompletedSteps(project.id)
        )
      },
      frictionRate: { projectID in

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
          frictionRate: manualD.frictionRate(
            .init(
              externalStaticPressure: staticPressure,
              componentPressureLosses: database.componentLoss.fetch(projectID),
              totalEffectiveLength: Int(totalEquivalentLength)
            )
          )
        )
      }
    )
  }

}
