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
    public var fetch: @Sendable (Project.ID) async throws -> [EffectiveLength]
    public var fetchMax: @Sendable (Project.ID) async throws -> EffectiveLength.MaxContainer
    public var get: @Sendable (EffectiveLength.ID) async throws -> EffectiveLength?
    public var update: @Sendable (EffectiveLength.Update) async throws -> EffectiveLength
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
        try await EffectiveLengthModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id, .equal, projectID)
          .all()
          .map { try $0.toDTO() }
      },
      fetchMax: { projectID in
        let effectiveLengths = try await EffectiveLengthModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id, .equal, projectID)
          .all()
          .map { try $0.toDTO() }

        return .init(
          supply: effectiveLengths.filter({ $0.type == .supply })
            .sorted(by: { $0.totalEquivalentLength > $1.totalEquivalentLength })
            .first,
          return: effectiveLengths.filter({ $0.type == .return })
            .sorted(by: { $0.totalEquivalentLength > $1.totalEquivalentLength })
            .first
        )

      },
      get: { id in
        try await EffectiveLengthModel.find(id, on: database).map { try $0.toDTO() }
      },
      update: { updates in
        guard let model = try await EffectiveLengthModel.find(updates.id, on: database) else {
          throw NotFoundError()
        }
        if try model.applyUpdates(updates) {
          try await model.save(on: database)
        }
        return try model.toDTO()
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
        .field(
          "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
        )
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

  func applyUpdates(_ updates: EffectiveLength.Update) throws -> Bool {
    var hasUpdates = false
    if let name = updates.name, name != self.name {
      hasUpdates = true
      self.name = name
    }
    if let type = updates.type, type.rawValue != self.type {
      hasUpdates = true
      self.type = type.rawValue
    }
    if let straightLengths = updates.straightLengths, straightLengths != self.straightLengths {
      hasUpdates = true
      self.straightLengths = straightLengths
    }
    if let groups = updates.groups {
      hasUpdates = true
      self.groups = try JSONEncoder().encode(groups)
    }
    return hasUpdates
  }
}
