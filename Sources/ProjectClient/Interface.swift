import Dependencies
import DependenciesMacros
import Elementary
import ManualDClient
import ManualDCore
import Vapor

extension DependencyValues {
  public var projectClient: ProjectClient {
    get { self[ProjectClient.self] }
    set { self[ProjectClient.self] = newValue }
  }
}

/// Useful helper utilities for project's.
///
/// This is primarily used for implementing logic required to get the needed data
/// for the view controller to render views.
@DependencyClient
public struct ProjectClient: Sendable {

  public var saveFittingPath:
    @Sendable (User.ID, Project.ID, Fitting.PathSave) async throws -> EquivalentLength

  /// Calculates the room duct sizes for the given project.
  public var calculateRoomDuctSizes:
    @Sendable (Project.ID) async throws -> [DuctSizes.RoomContainer]

  /// Calculates room and trunk duct sizes from one project-detail load.
  public var calculateDuctSizes: @Sendable (Project.ID) async throws -> DuctSizes

  public var generatePdf: @Sendable (Project.ID) async throws -> Response
}

extension ProjectClient: TestDependencyKey {
  public static let testValue = Self()
}

extension ProjectClient {

  public struct CreateProjectResponse: Codable, Equatable, Sendable {

    public let projectID: Project.ID
    public let rooms: [Room]
    public let sensibleHeatRatio: Double?
    public let completedSteps: Project.CompletedSteps

    public init(
      projectID: Project.ID,
      rooms: [Room],
      sensibleHeatRatio: Double? = nil,
      completedSteps: Project.CompletedSteps
    ) {
      self.projectID = projectID
      self.rooms = rooms
      self.sensibleHeatRatio = sensibleHeatRatio
      self.completedSteps = completedSteps
    }
  }
}
