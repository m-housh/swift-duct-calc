import Fluent
import Foundation
import ManualDCore

extension DatabaseClient.FittingFavorites {
  static func live(database: any Database) -> Self {
    .init(
      fetch: { userID in
        try await FittingFavoriteModel.query(on: database).filter(\.$userID == userID)
          .sort(\.$fittingID).all().map { Fitting.ID(rawValue: $0.fittingID) }
      },
      set: { userID, fittingID, selected in
        let query = FittingFavoriteModel.query(on: database).filter(\.$userID == userID).filter(
          \.$fittingID == fittingID.rawValue)
        if selected {
          guard try await query.first() == nil else { return }
          let model = FittingFavoriteModel()
          model.userID = userID
          model.fittingID = fittingID.rawValue
          try await model.save(on: database)
        } else {
          try await query.delete()
        }
      })
  }
}

final class FittingFavoriteModel: Model, @unchecked Sendable {
  static let schema = "fitting_favorite"
  @ID(key: .id) var id: UUID?
  @Field(key: "userID") var userID: UUID
  @Field(key: "fittingID") var fittingID: String
  init() {}
}

struct FittingFavoriteMigration: AsyncMigration {
  func prepare(on database: any Database) async throws {
    try await database.schema(FittingFavoriteModel.schema).id()
      .field("userID", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
      .field("fittingID", .string, .required).unique(on: "userID", "fittingID").create()
  }
  func revert(on database: any Database) async throws {
    try await database.schema(FittingFavoriteModel.schema).delete()
  }
}
