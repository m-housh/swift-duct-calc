import Dependencies
import DependenciesMacros
import FluentKit
import ManualDCore

extension DependencyValues {
  /// The database dependency.
  public var database: DatabaseClient {
    get { self[DatabaseClient.self] }
    set { self[DatabaseClient.self] = newValue }
  }
}

/// Represents the database interactions used by the application.
@DependencyClient
public struct DatabaseClient: Sendable {
  /// Database migrations.
  public var migrations: Migrations
  /// Interactions with the projects table.
  public var projects: Projects
  /// Interactions with the rooms table.
  public var rooms: Rooms
  /// Interactions with the equipment table.
  public var equipment: Equipment
  /// Interactions with the component losses table.
  public var componentLosses: ComponentLosses
  /// Interactions with the equivalent lengths table.
  public var equivalentLengths: EquivalentLengths
  /// Interactions with the users table.
  public var users: Users
  /// Interactions with the user profiles table.
  public var userProfiles: UserProfiles
  /// Interactions with the trunk sizes table.
  public var trunkSizes: TrunkSizes

  @DependencyClient
  public struct ComponentLosses: Sendable {
    public var create:
      @Sendable (ComponentPressureLoss.Create) async throws -> ComponentPressureLoss
    public var delete: @Sendable (ComponentPressureLoss.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> [ComponentPressureLoss]
    public var get: @Sendable (ComponentPressureLoss.ID) async throws -> ComponentPressureLoss?
    public var update:
      @Sendable (ComponentPressureLoss.ID, ComponentPressureLoss.Update) async throws ->
        ComponentPressureLoss
  }

  @DependencyClient
  public struct EquivalentLengths: Sendable {
    public var create: @Sendable (EquivalentLength.Create) async throws -> EquivalentLength
    public var delete: @Sendable (EquivalentLength.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> [EquivalentLength]
    public var fetchMax: @Sendable (Project.ID) async throws -> EquivalentLength.MaxContainer
    public var get: @Sendable (EquivalentLength.ID) async throws -> EquivalentLength?
    public var update:
      @Sendable (EquivalentLength.ID, EquivalentLength.Update) async throws -> EquivalentLength
  }

  @DependencyClient
  public struct Equipment: Sendable {
    public var create: @Sendable (EquipmentInfo.Create) async throws -> EquipmentInfo
    public var delete: @Sendable (EquipmentInfo.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> EquipmentInfo?
    public var get: @Sendable (EquipmentInfo.ID) async throws -> EquipmentInfo?
    public var update:
      @Sendable (EquipmentInfo.ID, EquipmentInfo.Update) async throws -> EquipmentInfo
  }

  @DependencyClient
  public struct Migrations: Sendable {
    public var all: @Sendable () async throws -> [any AsyncMigration]

    public func callAsFunction() async throws -> [any AsyncMigration] {
      try await self.all()
    }
  }

  @DependencyClient
  public struct Projects: Sendable {
    public var create: @Sendable (User.ID, Project.Create) async throws -> Project
    public var delete: @Sendable (Project.ID) async throws -> Void
    public var detail: @Sendable (Project.ID) async throws -> Project.Detail?
    public var get: @Sendable (Project.ID) async throws -> Project?
    public var getCompletedSteps: @Sendable (Project.ID) async throws -> Project.CompletedSteps
    public var getSensibleHeatRatio: @Sendable (Project.ID) async throws -> Double?
    public var fetch: @Sendable (User.ID, PageRequest) async throws -> Page<Project>
    public var update: @Sendable (Project.ID, Project.Update) async throws -> Project
  }

  @DependencyClient
  public struct Rooms: Sendable {
    public var create: @Sendable (Project.ID, Room.Create) async throws -> Room
    public var createMany: @Sendable (Project.ID, [Room.Create]) async throws -> [Room]
    public var delete: @Sendable (Room.ID) async throws -> Void
    public var deleteRectangularSize:
      @Sendable (Room.ID, Room.RectangularSize.ID) async throws -> Room
    public var get: @Sendable (Room.ID) async throws -> Room?
    public var fetch: @Sendable (Project.ID) async throws -> [Room]
    public var update: @Sendable (Room.ID, Room.Update) async throws -> Room
    public var updateRectangularSize: @Sendable (Room.ID, Room.RectangularSize) async throws -> Room
  }

  @DependencyClient
  public struct TrunkSizes: Sendable {
    public var create: @Sendable (TrunkSize.Create) async throws -> TrunkSize
    public var delete: @Sendable (TrunkSize.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> [TrunkSize]
    public var get: @Sendable (TrunkSize.ID) async throws -> TrunkSize?
    public var update:
      @Sendable (TrunkSize.ID, TrunkSize.Update) async throws ->
        TrunkSize
  }

  @DependencyClient
  public struct UserProfiles: Sendable {
    public var create: @Sendable (User.Profile.Create) async throws -> User.Profile
    public var delete: @Sendable (User.Profile.ID) async throws -> Void
    public var fetch: @Sendable (User.ID) async throws -> User.Profile?
    public var get: @Sendable (User.Profile.ID) async throws -> User.Profile?
    public var update: @Sendable (User.Profile.ID, User.Profile.Update) async throws -> User.Profile
  }

  @DependencyClient
  public struct Users: Sendable {
    public var create: @Sendable (User.Create) async throws -> User
    public var delete: @Sendable (User.ID) async throws -> Void
    public var get: @Sendable (User.ID) async throws -> User?
    public var login: @Sendable (User.Login) async throws -> User.Token
    public var logout: @Sendable (User.Token.ID) async throws -> Void
    // public var token: @Sendable (User.ID) async throws -> User.Token
  }

}

extension DatabaseClient: TestDependencyKey {
  public static let testValue: DatabaseClient = Self(
    migrations: .testValue,
    projects: .testValue,
    rooms: .testValue,
    equipment: .testValue,
    componentLosses: .testValue,
    equivalentLengths: .testValue,
    users: .testValue,
    userProfiles: .testValue,
    trunkSizes: .testValue
  )

  public static func live(database: any Database) -> Self {
    .init(
      migrations: .liveValue,
      projects: .live(database: database),
      rooms: .live(database: database),
      equipment: .live(database: database),
      componentLosses: .live(database: database),
      equivalentLengths: .live(database: database),
      users: .live(database: database),
      userProfiles: .live(database: database),
      trunkSizes: .live(database: database)
    )
  }
}
