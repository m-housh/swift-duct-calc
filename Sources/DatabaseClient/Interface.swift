import Dependencies
import DependenciesMacros
import FluentKit
import ManualDCore

extension DependencyValues {
  public var database: DatabaseClient {
    get { self[DatabaseClient.self] }
    set { self[DatabaseClient.self] = newValue }
  }
}

@DependencyClient
public struct DatabaseClient: Sendable {
  public var migrations: Migrations
  public var projects: Projects
  public var rooms: Rooms
  public var equipment: Equipment
  public var componentLoss: ComponentLoss
}

extension DatabaseClient: TestDependencyKey {
  public static let testValue: DatabaseClient = Self(
    migrations: .testValue,
    projects: .testValue,
    rooms: .testValue,
    equipment: .testValue,
    componentLoss: .testValue
  )

  public static func live(database: any Database) -> Self {
    .init(
      migrations: .liveValue,
      projects: .live(database: database),
      rooms: .live(database: database),
      equipment: .live(database: database),
      componentLoss: .live(database: database)
    )
  }
}

extension DatabaseClient {
  @DependencyClient
  public struct Migrations: Sendable {
    public var run: @Sendable () async throws -> [any AsyncMigration]
  }
}

extension DatabaseClient.Migrations: TestDependencyKey {
  public static let testValue = Self()
}

extension DatabaseClient.Migrations: DependencyKey {
  public static let liveValue = Self(
    run: {
      [
        Project.Migrate(),
        ComponentPressureLoss.Migrate(),
        EquipmentInfo.Migrate(),
        Room.Migrate(),
      ]
    }
  )
}
