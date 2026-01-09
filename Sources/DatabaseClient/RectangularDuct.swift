// import Dependencies
// import DependenciesMacros
// import Fluent
// import Foundation
// import ManualDCore
//
// extension DatabaseClient {
//   @DependencyClient
//   public struct RectangularDuct: Sendable {
//     public var create:
//       @Sendable (DuctSizing.RectangularDuct.Create) async throws -> DuctSizing.RectangularDuct
//     public var delete: @Sendable (DuctSizing.RectangularDuct.ID) async throws -> Void
//     public var fetch: @Sendable (Room.ID) async throws -> [DuctSizing.RectangularDuct]
//     public var get:
//       @Sendable (DuctSizing.RectangularDuct.ID) async throws -> DuctSizing.RectangularDuct?
//     public var update:
//       @Sendable (DuctSizing.RectangularDuct.ID, DuctSizing.RectangularDuct.Update) async throws ->
//         DuctSizing.RectangularDuct
//   }
// }
//
// extension DatabaseClient.RectangularDuct: TestDependencyKey {
//   public static let testValue = Self()
//
//   public static func live(database: any Database) -> Self {
//     .init(
//       create: { request in
//         try request.validate()
//         let model = request.toModel()
//         try await model.save(on: database)
//         return try model.toDTO()
//       },
//       delete: { id in
//         guard let model = try await RectangularDuctModel.find(id, on: database) else {
//           throw NotFoundError()
//         }
//         try await model.delete(on: database)
//       },
//       fetch: { roomID in
//         try await RectangularDuctModel.query(on: database)
//           .with(\.$room)
//           .filter(\.$room.$id == roomID)
//           .all()
//           .map { try $0.toDTO() }
//       },
//       get: { id in
//         try await RectangularDuctModel.find(id, on: database)
//           .map { try $0.toDTO() }
//       },
//       update: { id, updates in
//         guard let model = try await RectangularDuctModel.find(id, on: database) else {
//           throw NotFoundError()
//         }
//         try updates.validate()
//         model.applyUpdates(updates)
//         if model.hasChanges {
//           try await model.save(on: database)
//         }
//         return try model.toDTO()
//       }
//     )
//   }
// }
//
// extension DuctSizing.RectangularDuct.Create {
//
//   func validate() throws(ValidationError) {
//     guard height > 0 else {
//       throw ValidationError("Rectangular duct size height should be greater than 0.")
//     }
//     if let register {
//       guard register > 0 else {
//         throw ValidationError("Rectangular duct size register should be greater than 0.")
//       }
//     }
//   }
//
//   func toModel() -> RectangularDuctModel {
//     .init(roomID: roomID, height: height)
//   }
// }
//
// extension DuctSizing.RectangularDuct.Update {
//
//   func validate() throws(ValidationError) {
//     if let height {
//       guard height > 0 else {
//         throw ValidationError("Rectangular duct size height should be greater than 0.")
//       }
//     }
//     if let register {
//       guard register > 0 else {
//         throw ValidationError("Rectangular duct size register should be greater than 0.")
//       }
//     }
//   }
// }
//
// extension DuctSizing.RectangularDuct {
//   struct Migrate: AsyncMigration {
//     let name = "CreateRectangularDuct"
//
//     func prepare(on database: any Database) async throws {
//       try await database.schema(RectangularDuctModel.schema)
//         .id()
//         .field("register", .int8)
//         .field("height", .int8, .required)
//         .field("roomID", .uuid, .required, .references(RoomModel.schema, "id", onDelete: .cascade))
//         .field("createdAt", .datetime)
//         .field("updatedAt", .datetime)
//         .create()
//     }
//
//     func revert(on database: any Database) async throws {
//       try await database.schema(RectangularDuctModel.schema).delete()
//     }
//   }
// }
//
// final class RectangularDuctModel: Model, @unchecked Sendable {
//
//   static let schema = "rectangularDuct"
//
//   @ID(key: .id)
//   var id: UUID?
//
//   @Parent(key: "roomID")
//   var room: RoomModel
//
//   @Field(key: "height")
//   var height: Int
//
//   @Field(key: "register")
//   var register: Int?
//
//   @Timestamp(key: "createdAt", on: .create, format: .iso8601)
//   var createdAt: Date?
//
//   @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
//   var updatedAt: Date?
//
//   init() {}
//
//   init(
//     id: UUID? = nil,
//     roomID: Room.ID,
//     register: Int? = nil,
//     height: Int
//   ) {
//     self.id = id
//     $room.id = roomID
//     self.register = register
//     self.height = height
//   }
//
//   func toDTO() throws -> DuctSizing.RectangularDuct {
//     return try .init(
//       id: requireID(),
//       roomID: $room.id,
//       register: register,
//       height: height,
//       createdAt: createdAt!,
//       updatedAt: updatedAt!
//     )
//   }
//
//   func applyUpdates(_ updates: DuctSizing.RectangularDuct.Update) {
//     if let height = updates.height, height != self.height {
//       self.height = height
//     }
//     if let register = updates.register, register != self.register {
//       self.register = register
//     }
//   }
// }
