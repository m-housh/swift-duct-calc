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
      create: { projectID, request in
        let model = try request.toModel(projectID: projectID)
        try await model.validateAndSave(on: database)
        return try model.toDTO()
      },
      createMany: { projectID, rooms in
        try await RoomModel.createMany(projectID: projectID, rooms: rooms, on: database)
      },
      importLoads: { projectID, userID, loads in
        try await RoomModel.importRows(
          projectID: projectID, userID: userID,
          rows: loads.rooms.map {
            .init(
              name: $0.name, level: $0.level, heatingLoad: $0.heatingLoad,
              coolingTotal: $0.coolingTotal, coolingSensible: $0.coolingSensible,
              registerCount: 1)
          },
          reportSHR: loads.sensibleHeatRatio, updateDistribution: false, on: database)
      },
      createFromCSV: { projectID, userID, rows in
        try await RoomModel.importRows(
          projectID: projectID, userID: userID, rows: rows,
          reportSHR: nil, updateDistribution: true, on: database)
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
        guard size.height > 0,
          size.register.map({ $0 > 0 && $0 <= model.registerCount }) ?? true
        else {
          throw ValidationError("Choose a valid register and a positive height.")
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

extension RoomModel {
  fileprivate static func createMany(
    projectID: Project.ID,
    rooms: [Room.Create],
    on database: any Database
  ) async throws -> [Room] {
    try await rooms.asyncMap { request in
      let model = try request.toModel(projectID: projectID)
      try await model.validateAndSave(on: database)
      return try model.toDTO()
    }
  }
}

extension Room.Create {

  func toModel(projectID: Project.ID) throws -> RoomModel {
    var registerCount = registerCount
    // Set register count appropriately when delegatedTo is set / changes.
    if delegatedTo != nil {
      registerCount = 0
    } else if registerCount == 0 {
      registerCount = 1
    }

    return .init(
      name: name,
      level: level?.rawValue,
      heatingLoad: heatingLoad,
      coolingLoad: coolingLoad,
      registerCount: registerCount,
      delegetedToID: delegatedTo,
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
        .field("level", .int16)
        .field("heatingLoad", .double, .required)
        .field("coolingLoad", .dictionary, .required)
        .field("registerCount", .int16, .required)
        .field("delegatedToID", .uuid, .references(RoomModel.schema, "id"))
        .field("rectangularSizes", .array)
        .field("createdAt", .string)
        .field("updatedAt", .string)
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

  @Field(key: "level")
  var level: Int?

  @Field(key: "heatingLoad")
  var heatingLoad: Double

  @Field(key: "coolingLoad")
  var coolingLoad: Room.CoolingLoad

  @Field(key: "registerCount")
  var registerCount: Int

  @OptionalParent(key: "delegatedToID")
  var room: RoomModel?

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
    level: Int? = nil,
    heatingLoad: Double,
    coolingLoad: Room.CoolingLoad,
    registerCount: Int,
    delegetedToID: UUID? = nil,
    rectangularSizes: [Room.RectangularSize]? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.name = name
    self.level = level
    self.heatingLoad = heatingLoad
    self.coolingLoad = coolingLoad
    self.registerCount = registerCount
    $room.id = delegetedToID
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
      level: level.map(Room.Level.init(rawValue:)),
      heatingLoad: heatingLoad,
      coolingLoad: coolingLoad,
      registerCount: registerCount,
      delegatedTo: $room.id,
      rectangularSizes: rectangularSizes,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: Room.Update) {

    if let name = updates.name, name != self.name {
      self.name = name
    }
    if let level = updates.level?.rawValue, level != self.level {
      self.level = level
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

      Validator.validate(\.registerCount, with: .greaterThanOrEquals($room.id == nil ? 1 : 0))
        .errorLabel("Register Count", inline: true)

      Validator.validate(\.rectangularSizes)

    }
  }

  func validateAndSave(on database: Database) async throws {
    try self.validate()
    if let delegateTo = $room.id {
      guard
        let parent =
          try await RoomModel
          .query(on: database)
          .with(\.$room)
          .filter(\.$id == delegateTo)
          .filter(\.$project.$id == $project.id)
          .first()
      else {
        throw ValidationError("Can not find room: \(delegateTo), to delegate airflow to.")
      }
      guard parent.$room.id == nil else {
        throw ValidationError(
          """
          Attempting to delegate to: \(parent.name), that delegates to: \(parent.$room.name)

          Unable to delegate airflow to a room that already delegates it's airflow.
          """

        )
      }
    }
    try await save(on: database)
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
