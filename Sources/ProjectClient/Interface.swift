import Dependencies
import DependenciesMacros
import ManualDClient
import ManualDCore

extension DependencyValues {
  public var projectClient: ProjectClient {
    get { self[ProjectClient.self] }
    set { self[ProjectClient.self] = newValue }
  }
}

@DependencyClient
public struct ProjectClient: Sendable {
  public var calculateDuctSizes: @Sendable (Project.ID) async throws -> DuctSizeResponse
  public var calculateRoomDuctSizes:
    @Sendable (Project.ID) async throws -> [DuctSizing.RoomContainer]
  public var calculateTrunkDuctSizes:
    @Sendable (Project.ID) async throws -> [DuctSizing.TrunkContainer]

  public var createProject:
    @Sendable (User.ID, Project.Create) async throws -> CreateProjectResponse

  public var frictionRate: @Sendable (Project.ID) async throws -> FrictionRateResponse
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

  public struct DuctSizeResponse: Codable, Equatable, Sendable {
    public let rooms: [DuctSizing.RoomContainer]
    public let trunks: [DuctSizing.TrunkContainer]

    public init(
      rooms: [DuctSizing.RoomContainer],
      trunks: [DuctSizing.TrunkContainer]
    ) {
      self.rooms = rooms
      self.trunks = trunks
    }
  }

  public struct FrictionRateResponse: Codable, Equatable, Sendable {

    public let componentLosses: [ComponentPressureLoss]
    public let equivalentLengths: EffectiveLength.MaxContainer
    public let frictionRate: ManualDClient.FrictionRateResponse?

    public init(
      componentLosses: [ComponentPressureLoss],
      equivalentLengths: EffectiveLength.MaxContainer,
      frictionRate: ManualDClient.FrictionRateResponse? = nil
    ) {
      self.componentLosses = componentLosses
      self.equivalentLengths = equivalentLengths
      self.frictionRate = frictionRate
    }
  }
}
