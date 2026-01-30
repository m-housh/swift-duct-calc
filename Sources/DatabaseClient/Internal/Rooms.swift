import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

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
      deleteRectangularSize: { roomID, rectangularDuctID in
        guard let model = try await RoomModel.find(roomID, on: database) else {
          throw NotFoundError()
        }
        model.rectangularSizes?.removeAll {
          $0.id == rectangularDuctID
        }
        if model.rectangularSizes?.count == 0 {
          model.rectangularSizes = nil
        }
        if model.hasChanges {
          try await model.save(on: database)
        }
        return try model.toDTO()
      },
      get: { id in
        try await RoomModel.find(id, on: database).map { try $0.toDTO() }
      },
      fetch: { projectID in
        try await RoomModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id, .equal, projectID)
          .sort(\.$name, .ascending)
          .all()
          .map { try $0.toDTO() }
      },
      update: { id, updates in
        guard let model = try await RoomModel.find(id, on: database) else {
          throw NotFoundError()
        }

        try updates.validate()
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.save(on: database)
        }
        return try model.toDTO()
      },
      updateRectangularSize: { id, size in
        guard let model = try await RoomModel.find(id, on: database) else {
          throw NotFoundError()
        }
        var rectangularSizes = model.rectangularSizes ?? []
        rectangularSizes.removeAll {
          $0.id == size.id
        }
        rectangularSizes.append(size)
        model.rectangularSizes = rectangularSizes
        try await model.save(on: database)
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
      coolingTotal: coolingTotal,
      coolingSensible: coolingSensible,
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
    guard coolingTotal >= 0 else {
      throw ValidationError("Room cooling total should not be less than 0.")
    }
    if let coolingSensible {
      guard coolingSensible >= 0 else {
        throw ValidationError("Room cooling sensible should not be less than 0.")
      }
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
    if let coolingTotal {
      guard coolingTotal >= 0 else {
        throw ValidationError("Room cooling total should not be less than 0.")
      }
    }
    if let coolingSensible {
      guard coolingSensible >= 0 else {
        throw ValidationError("Room cooling sensible should not be less than 0.")
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
        .field("coolingTotal", .double, .required)
        .field("coolingSensible", .double)
        .field("registerCount", .int8, .required)
        .field("rectangularSizes", .array)
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

  @Field(key: "coolingTotal")
  var coolingTotal: Double

  @Field(key: "coolingSensible")
  var coolingSensible: Double?

  @Field(key: "registerCount")
  var registerCount: Int

  @Field(key: "rectangularSizes")
  var rectangularSizes: [Room.RectangularSize]?

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
    coolingTotal: Double,
    coolingSensible: Double? = nil,
    registerCount: Int,
    rectangularSizes: [Room.RectangularSize]? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingTotal = coolingTotal
    self.coolingSensible = coolingSensible
    self.registerCount = registerCount
    self.rectangularSizes = rectangularSizes
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
      coolingTotal: coolingTotal,
      coolingSensible: coolingSensible,
      registerCount: registerCount,
      rectangularSizes: rectangularSizes,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: Room.Update) {

    if let name = updates.name, name != self.name {
      self.name = name
    }
    if let heatingLoad = updates.heatingLoad, heatingLoad != self.heatingLoad {
      self.heatingLoad = heatingLoad
    }
    if let coolingTotal = updates.coolingTotal, coolingTotal != self.coolingTotal {
      self.coolingTotal = coolingTotal
    }
    if let coolingSensible = updates.coolingSensible, coolingSensible != self.coolingSensible {
      self.coolingSensible = coolingSensible
    }
    if let registerCount = updates.registerCount, registerCount != self.registerCount {
      self.registerCount = registerCount
    }
    if let rectangularSizes = updates.rectangularSizes, rectangularSizes != self.rectangularSizes {
      self.rectangularSizes = rectangularSizes
    }

  }

}
