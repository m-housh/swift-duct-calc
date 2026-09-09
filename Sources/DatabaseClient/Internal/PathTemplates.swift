import Dependencies
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient.PathTemplates: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { userID, configuration in
        try configuration.validate()
        @Dependency(\.uuid) var uuid
        let model = PathTemplateModel(
          userID: userID, revision: uuid(), configuration: try JSONEncoder().encode(configuration)
        )
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { userID, id in
        guard try await PathTemplateModel.owned(userID, id: id, on: database).first() != nil else {
          throw NotFoundError()
        }
        try await PathTemplateModel.owned(userID, id: id, on: database).delete()
      },
      fetch: { userID in
        try await PathTemplateModel.query(on: database)
          .filter(\.$user.$id == userID)
          .sort(\.$createdAt, .ascending)
          .all().map { try $0.toDTO() }
      },
      get: { userID, id in
        try await PathTemplateModel.owned(userID, id: id, on: database)
          .first().map { try $0.toDTO() }
      },
      update: { userID, id, expectedRevision, configuration in
        try configuration.validate()
        let encoded = try JSONEncoder().encode(configuration)
        @Dependency(\.uuid) var uuid
        let revision = uuid()
        return try await database.transaction { transaction in
          // The conditional update holds the row lock until the read completes.
          // A unique revision distinguishes our write from another editor's write.
          try await PathTemplateModel.owned(userID, id: id, on: transaction)
            .filter(\.$revision == expectedRevision)
            .set(\.$revision, to: revision)
            .set(\.$configuration, to: encoded)
            .update()
          guard
            let saved = try await PathTemplateModel.owned(userID, id: id, on: transaction)
              .first()
          else { throw NotFoundError() }
          guard saved.revision == revision else { throw PathTemplateConflictError() }
          return try saved.toDTO()
        }
      }
    )
  }
}

public struct PathTemplateConflictError: Error, Sendable {
  public init() {}
}

extension PathTemplate {
  struct Migrate: AsyncMigration {
    let name = "CreatePathTemplate"

    func prepare(on database: any Database) async throws {
      try await database.schema(PathTemplateModel.schema)
        .id()
        .field("userID", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
        .field("revision", .uuid, .required)
        .field("configuration", .data, .required)
        .field("createdAt", .string)
        .field("updatedAt", .string)
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(PathTemplateModel.schema).delete()
    }
  }
}

final class PathTemplateModel: Model, @unchecked Sendable {
  static let schema = "path_template"

  @ID(key: .id) var id: UUID?
  @Parent(key: "userID") var user: UserModel
  @Field(key: "revision") var revision: UUID
  @Field(key: "configuration") var configuration: Data
  @Timestamp(key: "createdAt", on: .create, format: .iso8601) var createdAt: Date?
  @Timestamp(key: "updatedAt", on: .update, format: .iso8601) var updatedAt: Date?

  init() {}

  init(userID: User.ID, revision: UUID, configuration: Data) {
    self.$user.id = userID
    self.revision = revision
    self.configuration = configuration
  }

  static func owned(_ userID: User.ID, id: PathTemplate.ID, on database: any Database)
    -> QueryBuilder<PathTemplateModel>
  {
    query(on: database).filter(\.$id == id).filter(\.$user.$id == userID)
  }

  func toDTO() throws -> PathTemplate {
    guard let createdAt, let updatedAt else {
      throw ValidationError("The saved template is missing its timestamps.")
    }
    return try .init(
      id: requireID(), userID: $user.id, revision: revision,
      configuration: JSONDecoder().decode(PathTemplate.Configuration.self, from: configuration),
      createdAt: createdAt, updatedAt: updatedAt
    )
  }
}
