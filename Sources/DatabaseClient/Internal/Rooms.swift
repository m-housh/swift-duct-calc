import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import Validations

extension DatabaseClient.Rooms: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = try request.toModel()
        try await model.validateAndSave(on: database)
        return try model.toDTO()
      },
      createMany: { rooms in
        try await rooms.asyncMap { request in
          let model = try request.toModel()
          try await model.validateAndSave(on: database)
          return try model.toDTO()
        }
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
          try await model.validateAndSave(on: database)
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
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.validateAndSave(on: database)
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

  func toModel() throws -> RoomModel {
    return .init(
      name: name,
      heatingLoad: heatingLoad,
      coolingLoad: coolingLoad,
      registerCount: registerCount,
      projectID: projectID
    )
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
        .field("coolingLoad", .dictionary, .required)
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

final class RoomModel: Model, @unchecked Sendable, Validatable {

  static let schema = "room"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "name")
  var name: String

  @Field(key: "heatingLoad")
  var heatingLoad: Double

  @Field(key: "coolingLoad")
  var coolingLoad: Room.CoolingLoad

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
    coolingLoad: Room.CoolingLoad,
    registerCount: Int,
    rectangularSizes: [Room.RectangularSize]? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.name = name
    self.heatingLoad = heatingLoad
    self.coolingLoad = coolingLoad
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
      coolingLoad: coolingLoad,
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
    if let coolingLoad = updates.coolingLoad, coolingLoad != self.coolingLoad {
      self.coolingLoad = coolingLoad
    }
    if let registerCount = updates.registerCount, registerCount != self.registerCount {
      self.registerCount = registerCount
    }
    if let rectangularSizes = updates.rectangularSizes, rectangularSizes != self.rectangularSizes {
      self.rectangularSizes = rectangularSizes
    }

  }

  var body: some Validation<RoomModel> {
    Validator.accumulating {
      Validator.validate(\.name, with: .notEmpty())
        .errorLabel("Name", inline: true)

      Validator.validate(\.heatingLoad, with: .greaterThanOrEquals(0))
        .errorLabel("Heating Load", inline: true)

      Validator.validate(\.coolingLoad)
        .errorLabel("Cooling Load", inline: true)

      Validator.validate(\.registerCount, with: .greaterThanOrEquals(1))
        .errorLabel("Register Count", inline: true)

      Validator.validate(\.rectangularSizes)

    }
  }
}

extension Room.CoolingLoad: Validatable {

  public var body: some Validation<Self> {
    Validator.accumulating {
      // Ensure that at least one of the values is not nil.
      Validator.oneOf {
        Validator.validate(\.total, with: .notNil())
          .errorLabel("Total or Sensible", inline: true)
        Validator.validate(\.sensible, with: .notNil())
          .errorLabel("Total or Sensible", inline: true)
      }

      Validator.validate(\.total, with: Double.greaterThan(0).optional())
      Validator.validate(\.sensible, with: Double.greaterThan(0).optional())
    }
  }

}

extension Room.RectangularSize: Validatable {

  public var body: some Validation<Self> {
    Validator.accumulating {
      Validator.validate(\.register, with: Int.greaterThanOrEquals(1).optional())
        .errorLabel("Register", inline: true)

      Validator.validate(\.height, with: Int.greaterThanOrEquals(1))
        .errorLabel("Height", inline: true)
    }
  }
}
