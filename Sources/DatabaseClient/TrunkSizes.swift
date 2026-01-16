import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
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
}

extension DatabaseClient.TrunkSizes: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        try request.validate()

        let trunk = request.toModel()
        var roomProxies = [TrunkSize.RoomProxy]()

        try await trunk.save(on: database)

        for (roomID, registers) in request.rooms {
          guard let room = try await RoomModel.find(roomID, on: database) else {
            throw NotFoundError()
          }
          let model = try TrunkRoomModel(
            trunkID: trunk.requireID(),
            roomID: room.requireID(),
            registers: registers,
            type: request.type
          )
          try await model.save(on: database)
          try await roomProxies.append(model.toDTO(on: database))
        }

        return try .init(
          id: trunk.requireID(),
          projectID: trunk.$project.id,
          type: .init(rawValue: trunk.type)!,
          rooms: roomProxies
        )
      },
      delete: { id in
        guard let model = try await TrunkModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      fetch: { projectID in
        try await TrunkModel.query(on: database)
          .with(\.$project)
          .with(\.$rooms)
          .filter(\.$project.$id == projectID)
          .all()
          .toDTO(on: database)
      },
      get: { id in
        guard let model = try await TrunkModel.find(id, on: database) else {
          return nil
        }
        return try await model.toDTO(on: database)
      },
      update: { id, updates in
        guard
          let model =
            try await TrunkModel
            .query(on: database)
            .with(\.$rooms)
            .filter(\.$id == id)
            .first()
        else {
          throw NotFoundError()
        }
        try updates.validate()
        try await model.applyUpdates(updates, on: database)
        return try await model.toDTO(on: database)
      }
    )
  }
}

extension TrunkSize.Create {

  func validate() throws(ValidationError) {
    guard rooms.count > 0 else {
      throw ValidationError("Trunk size should have associated rooms / registers.")
    }
    if let height {
      guard height > 0 else {
        throw ValidationError("Trunk size height should be greater than 0.")
      }
    }
  }

  func toModel() -> TrunkModel {
    .init(
      projectID: projectID,
      type: type,
      height: height,
      name: name
    )
  }
}

extension TrunkSize.Update {
  func validate() throws(ValidationError) {
    if let rooms {
      guard rooms.count > 0 else {
        throw ValidationError("Trunk size should have associated rooms / registers.")
      }
    }
    if let height {
      guard height > 0 else {
        throw ValidationError("Trunk size height should be greater than 0.")
      }
    }
  }
}

extension TrunkSize {

  struct Migrate: AsyncMigration {
    let name = "CreateTrunkSize"

    func prepare(on database: any Database) async throws {
      try await database.schema(TrunkModel.schema)
        .id()
        .field("height", .int8)
        .field("name", .string)
        .field("type", .string, .required)
        .field(
          "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
        )
        .create()

      try await database.schema(TrunkRoomModel.schema)
        .id()
        .field("registers", .array(of: .int), .required)
        .field("type", .string, .required)
        .field(
          "trunkID", .uuid, .required, .references(TrunkModel.schema, "id", onDelete: .cascade)
        )
        .field(
          "roomID", .uuid, .required, .references(RoomModel.schema, "id", onDelete: .cascade)
        )
        .unique(on: "trunkID", "roomID", "type")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(TrunkRoomModel.schema).delete()
      try await database.schema(TrunkModel.schema).delete()
    }
  }
}

// Pivot table for associating rooms and trunks.
final class TrunkRoomModel: Model, @unchecked Sendable {

  static let schema = "room+trunk"

  @ID(key: .id)
  var id: UUID?

  @Parent(key: "trunkID")
  var trunk: TrunkModel

  @Parent(key: "roomID")
  var room: RoomModel

  @Field(key: "registers")
  var registers: [Int]

  @Field(key: "type")
  var type: String

  init() {}

  init(
    id: UUID? = nil,
    trunkID: TrunkModel.IDValue,
    roomID: RoomModel.IDValue,
    registers: [Int],
    type: TrunkSize.TrunkType
  ) {
    self.id = id
    $trunk.id = trunkID
    $room.id = roomID
    self.registers = registers
    self.type = type.rawValue
  }

  func toDTO(on database: any Database) async throws -> TrunkSize.RoomProxy {
    guard let room = try await RoomModel.find($room.id, on: database) else {
      throw NotFoundError()
    }
    return .init(
      room: try room.toDTO(),
      registers: registers
    )
  }

}

final class TrunkModel: Model, @unchecked Sendable {

  static let schema = "trunk"

  @ID(key: .id)
  var id: UUID?

  @Parent(key: "projectID")
  var project: ProjectModel

  @OptionalField(key: "height")
  var height: Int?

  @Field(key: "type")
  var type: String

  @OptionalField(key: "name")
  var name: String?

  @Children(for: \.$trunk)
  var rooms: [TrunkRoomModel]

  init() {}

  init(
    id: UUID? = nil,
    projectID: Project.ID,
    type: TrunkSize.TrunkType,
    height: Int? = nil,
    name: String? = nil
  ) {
    self.id = id
    $project.id = projectID
    self.height = height
    self.type = type.rawValue
    self.name = name
  }

  func toDTO(on database: any Database) async throws -> TrunkSize {
    let rooms = try await withThrowingTaskGroup(of: TrunkSize.RoomProxy.self) { group in
      for room in self.rooms {
        group.addTask {
          try await room.toDTO(on: database)
        }
      }

      return try await group.reduce(into: [TrunkSize.RoomProxy]()) {
        $0.append($1)
      }

    }

    return try .init(
      id: requireID(),
      projectID: $project.id,
      type: .init(rawValue: type)!,
      rooms: rooms,
      height: height,
      name: name
    )

  }

  func applyUpdates(
    _ updates: TrunkSize.Update,
    on database: any Database
  ) async throws {
    if let type = updates.type, type.rawValue != self.type {
      self.type = type.rawValue
    }
    if let height = updates.height, height != self.height {
      self.height = height
    }
    if let name = updates.name, name != self.name {
      self.name = name
    }
    if hasChanges {
      try await self.save(on: database)
    }

    guard let updateRooms = updates.rooms else {
      return
    }

    // Update rooms.
    let rooms = try await TrunkRoomModel.query(on: database)
      .with(\.$room)
      .filter(\.$trunk.$id == requireID())
      .all()

    for (roomID, registers) in updateRooms {
      if let currRoom = rooms.first(where: { $0.$room.id == roomID }) {
        database.logger.debug("CURRENT ROOM: \(currRoom.room.name)")
        if registers != currRoom.registers {
          database.logger.debug("Updating registers for: \(currRoom.room.name)")
          currRoom.registers = registers
        }
        if currRoom.hasChanges {
          try await currRoom.save(on: database)
        }
      } else {
        database.logger.debug("CREATING NEW TrunkRoomModel")
        let newModel = try TrunkRoomModel(
          trunkID: requireID(),
          roomID: roomID,
          registers: registers,
          type: .init(rawValue: type)!
        )
        try await newModel.save(on: database)
      }
    }

    let roomsToDelete = rooms.filter {
      !updateRooms.keys.contains($0.$room.id)
    }

    for room in roomsToDelete {
      try await room.delete(on: database)
    }

    database.logger.debug("DONE WITH UPDATES")

  }
}

extension Array where Element == TrunkModel {

  func toDTO(on database: any Database) async throws -> [TrunkSize] {
    try await withThrowingTaskGroup(of: TrunkSize.self) { group in
      for model in self {
        group.addTask {
          try await model.toDTO(on: database)
        }
      }

      return try await group.reduce(into: [TrunkSize]()) {
        $0.append($1)
      }
    }
  }
}
