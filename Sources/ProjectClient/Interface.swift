import Dependencies
import DependenciesMacros
import Elementary
import ManualDClient
import ManualDCore

extension DependencyValues {
  public var projectClient: ProjectClient {
    get { self[ProjectClient.self] }
    set { self[ProjectClient.self] = newValue }
  }
}

/// Useful helper utilities for project's.
///
/// This is primarily used for implementing logic required to get the needed data
/// for the view controller client to render views.
@DependencyClient
public struct ProjectClient: Sendable {
  public var calculateDuctSizes: @Sendable (Project.ID) async throws -> DuctSizes
  public var calculateRoomDuctSizes:
    @Sendable (Project.ID) async throws -> [DuctSizes.RoomContainer]
  public var calculateTrunkDuctSizes:
    @Sendable (Project.ID) async throws -> [DuctSizes.TrunkContainer]

  public var createProject:
    @Sendable (User.ID, Project.Create) async throws -> CreateProjectResponse

  public var frictionRate: @Sendable (Project.ID) async throws -> FrictionRateResponse

  // FIX: Name to something to do with generating a pdf, just experimenting now.
  public var toMarkdown: @Sendable (Project.ID) async throws -> String
  public var toHTML: @Sendable (Project.ID) async throws -> (any HTML & Sendable)
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

  public struct FrictionRateResponse: Codable, Equatable, Sendable {

    public let componentLosses: [ComponentPressureLoss]
    public let equivalentLengths: EffectiveLength.MaxContainer
    public let frictionRate: FrictionRate?

    public init(
      componentLosses: [ComponentPressureLoss],
      equivalentLengths: EffectiveLength.MaxContainer,
      frictionRate: FrictionRate? = nil
    ) {
      self.componentLosses = componentLosses
      self.equivalentLengths = equivalentLengths
      self.frictionRate = frictionRate
    }
  }
}
