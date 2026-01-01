import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
  @DependencyClient
  public struct EffectiveLengthClient: Sendable {
    public var create: @Sendable (EffectiveLength.Create) async throws -> EffectiveLength
    public var delete: @Sendable (EffectiveLength.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> EffectiveLength?
    public var get: @Sendable (EffectiveLength.ID) async throws -> EffectiveLength?
  }
}

extension DatabaseClient.EffectiveLengthClient: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = try request.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await EffectiveLengthModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      fetch: { projectID in
        guard
          let model = try await EffectiveLengthModel.query(on: database)
            .filter("projectID", .equal, projectID)
            .first()
        else {
          throw NotFoundError()
        }

        return try model.toDTO()
      },
      get: { id in
        try await EffectiveLengthModel.find(id, on: database).map { try $0.toDTO() }
      }
    )
  }
}

extension EffectiveLength.Create {

  func toModel() throws -> EffectiveLengthModel {
    try validate()
    return try .init(
      name: name,
      type: type.rawValue,
      straightLengths: straightLengths,
      groups: JSONEncoder().encode(groups),
      projectID: projectID
    )
  }

  func validate() throws(ValidationError) {
    guard !name.isEmpty else {
      throw ValidationError("Effective length name can not be empty.")
    }
  }
}

extension EffectiveLength {

  struct Migrate: AsyncMigration {
    let name = "CreateEffectiveLength"

    func prepare(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema)
        .id()
        .field("name", .string, .required)
        .field("type", .string, .required)
        .field("straightLengths", .array(of: .int))
        .field("groups", .data)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .field("projectID", .uuid, .required, .references(ProjectModel.schema, "id"))
        .unique(on: "projectID", "name", "type")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema).delete()
    }
  }
}

// TODO: Add total effective length field so that we can lookup / compare which one is
//       the longest for a given project.
final class EffectiveLengthModel: Model, @unchecked Sendable {

  static let schema = "effective_length"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "name")
  var name: String

  @Field(key: "type")
  var type: String

  @Field(key: "straightLengths")
  var straightLengths: [Int]

  @Field(key: "groups")
  var groups: Data

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
    type: String,
    straightLengths: [Int],
    groups: Data,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.straightLengths = straightLengths
    self.groups = groups
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    $project.id = projectID
  }

  func toDTO() throws -> EffectiveLength {
    try .init(
      id: requireID(),
      projectID: $project.id,
      name: name,
      type: .init(rawValue: type)!,
      straightLengths: straightLengths,
      groups: JSONDecoder().decode([EffectiveLength.Group].self, from: groups),
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }
}
