import Dependencies
import DependenciesMacros
import ManualDCore

extension DependencyValues {
  public var projectClient: ProjectClient {
    get { self[ProjectClient.self] }
    set { self[ProjectClient.self] = newValue }
  }
}

@DependencyClient
public struct ProjectClient: Sendable {
  public var calculateDuctSizes: @Sendable (Project.ID) async throws -> ProjectResponse
}

extension ProjectClient: TestDependencyKey {
  public static let testValue = Self()
}

extension ProjectClient {

  public struct ProjectResponse: Codable, Equatable, Sendable {
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
}
