import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
  @DependencyClient
  public struct Rooms: Sendable {
    public var create: @Sendable (Room.Create) async throws -> Room
    public var delete: @Sendable (Room.ID) async throws -> Void
    public var get: @Sendable (Room.ID) async throws -> Room?
    public var fetch: @Sendable (Project.ID) async throws -> [Room]
    public var update: @Sendable (Room.Update) async throws -> Room
  }
}

extension DatabaseClient.Rooms: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = try request.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await RoomModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      get: { id in
        try await RoomModel.find(id, on: database).map { try $0.toDTO() }
      },
      fetch: { projectID in
        try await RoomModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id, .equal, projectID)
          .all()
          .map { try $0.toDTO() }
      },
      update: { updates in
        guard let model = try await RoomModel.find(updates.id, on: database) else {
          throw NotFoundError()
        }

        try updates.validate()
        if model.applyUpdates(updates) {
          try await model.save(on: database)
        }
        return try model.toDTO()
      }
    )
  }
}

extension Room.Create {

  func toModel() throws(ValidationError) -> RoomModel {
    try validate()
    return .init(
      name: name,
      heatingLoad: heatingLoad,
      coolingLoad: coolingLoad,
      registerCount: registerCount,
      projectID: projectID
    )
  }

  func validate() throws(ValidationError) {
    guard !name.isEmpty else {
      throw ValidationError("Room name should not be empty.")
    }
    guard heatingLoad >= 0 else {
      throw ValidationError("Room heating load should not be less than 0.")
    }
    guard coolingLoad >= 0 else {
      throw ValidationError("Room cooling total should not be less than 0.")
    }
    guard registerCount >= 1 else {
      throw ValidationError("Room cooling sensible should not be less than 1.")
    }
  }
}

extension Room.Update {

  func validate() throws(ValidationError) {
    if let name {
      guard !name.isEmpty else {
        throw ValidationError("Room name should not be empty.")
      }
    }
    if let heatingLoad {
      guard heatingLoad >= 0 else {
        throw ValidationError("Room heating load should not be less than 0.")
      }
    }
    if let coolingLoad {
      guard coolingLoad >= 0 else {
        throw ValidationError("Room cooling total should not be less than 0.")
      }
    }
    if let registerCount {
      guard registerCount >= 1 else {
        throw ValidationError("Room cooling sensible should not be less than 1.")
      }
    }
  }
}

extension Room {
  struct Migrate: AsyncMigration {
    let name = "CreateRoom"

    func prepare(on database: any Database) async throws {
      try await database.schema(RoomModel.schema)
        .id()
        .field("name", .string, .required)
        .field("heatingLoad", .double, .required)
        .field("coolingLoad", .double, .required)
        .field("registerCount", .int8, .required)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .field(
          "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
        )
        .unique(on: "projectID", "name")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(RoomModel.schema).delete()
    }
  }
}

final class RoomModel: Model, @unchecked Sendable {

  static let schema = "room"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "name")
  var name: String

  @Field(key: "heatingLoad")
  var heatingLoad: Double

  @Field(key: "coolingLoad")
  var coolingLoad: Double

  @Field(key: "registerCount")
  var registerCount: Int

  @Timestamp(key: "createdAt", on: .create, format: .iso8601)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
  var updatedAt: Date?

  @Parent(key: "projectID")
  var project: ProjectModel

  init() {}

  init(
    id: UUID? = nil,
    name: String,
    heatingLoad: Double,
    coolingLoad: Double,
    registerCount: Int,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingLoad = coolingLoad
    self.registerCount = registerCount
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    $project.id = projectID
  }

  func toDTO() throws -> Room {
    try .init(
      id: requireID(),
      projectID: $project.id,
      name: name,
      heatingLoad: heatingLoad,
      coolingLoad: coolingLoad,
      registerCount: registerCount,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: Room.Update) -> Bool {
    var hasUpdates = false

    if let name = updates.name, name != self.name {
      hasUpdates = true
      self.name = name
    }
    if let heatingLoad = updates.heatingLoad, heatingLoad != self.heatingLoad {
      hasUpdates = true
      self.heatingLoad = heatingLoad
    }
    if let coolingLoad = updates.coolingLoad, coolingLoad != self.coolingLoad {
      hasUpdates = true
      self.coolingLoad = coolingLoad
    }
    if let registerCount = updates.registerCount, registerCount != self.registerCount {
      hasUpdates = true
      self.registerCount = registerCount
    }
    return hasUpdates
  }

}
