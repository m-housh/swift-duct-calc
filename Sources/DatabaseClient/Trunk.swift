import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
  @DependencyClient
  public struct TrunkSizes: Sendable {
    public var create: @Sendable (DuctSizing.TrunkSize.Create) async throws -> DuctSizing.TrunkSize
    public var delete: @Sendable (DuctSizing.TrunkSize.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> [DuctSizing.TrunkSize]
    public var get: @Sendable (DuctSizing.TrunkSize.ID) async throws -> DuctSizing.TrunkSize?
  }
}

extension DatabaseClient.TrunkSizes: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        try request.validate()

        let trunk = request.toModel()
        var roomProxies = [DuctSizing.TrunkSize.RoomProxy]()

        try await trunk.save(on: database)

        for (roomID, registers) in request.rooms {
          guard let room = try await RoomModel.find(roomID, on: database) else {
            throw NotFoundError()
          }
          let model = try TrunkRoomModel(
            trunkID: trunk.requireID(),
            roomID: room.requireID(),
            registers: registers
          )
          try await model.save(on: database)
          try roomProxies.append(model.toDTO())
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
          .with(\.$rooms)
          .with(\.$project)
          .filter(\.$project.$id == projectID)
          .all()
          .map { try $0.toDTO() }
      },
      get: { id in
        try await TrunkModel.find(id, on: database)
          .map { try $0.toDTO() }
      }
    )
  }
}

extension DuctSizing.TrunkSize.Create {

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
      height: height
    )
  }

}

extension DuctSizing.TrunkSize {

  struct Migrate: AsyncMigration {
    let name = "CreateTrunkSize"

    func prepare(on database: any Database) async throws {
      try await database.schema(TrunkModel.schema)
        .id()
        .field("height", .int8)
        .field("type", .string, .required)
        .field(
          "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
        )
        .create()

      try await database.schema(TrunkRoomModel.schema)
        .id()
        .field("registers", .array(of: .int), .required)
        .field(
          "trunkID", .uuid, .required, .references(TrunkModel.schema, "id", onDelete: .cascade)
        )
        .field(
          "roomID", .uuid, .required, .references(RoomModel.schema, "id", onDelete: .cascade)
        )
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

  init() {}

  init(
    id: UUID? = nil,
    trunkID: TrunkModel.IDValue,
    roomID: RoomModel.IDValue,
    registers: [Int]
  ) {
    self.id = id
    $trunk.id = trunkID
    $room.id = roomID
    self.registers = registers
  }

  func toDTO() throws -> DuctSizing.TrunkSize.RoomProxy {
    .init(
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

  @Field(key: "height")
  var height: Int?

  @Field(key: "type")
  var type: String

  @Children(for: \.$trunk)
  var rooms: [TrunkRoomModel]

  init() {}

  init(
    id: UUID? = nil,
    projectID: Project.ID,
    type: DuctSizing.TrunkSize.TrunkType,
    height: Int? = nil,
  ) {
    self.id = id
    $project.id = projectID
    self.height = height
    self.type = type.rawValue
  }

  func toDTO() throws -> DuctSizing.TrunkSize {
    try .init(
      id: requireID(),
      projectID: $project.id,
      type: .init(rawValue: type)!,
      rooms: rooms.map { try $0.toDTO() },
      height: height
    )

  }
}
