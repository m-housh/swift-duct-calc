import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import Validations

extension DatabaseClient.EquivalentLengths: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      updateIfUnchanged: { baseline, updates in
        try await updatePath(on: database, baseline: baseline, updates: updates)
      },
      create: { request in
        let model = try request.toModel()
        model.revision = UUID()
        try await model.validateAndSave(on: database)
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
      update: { id, updates in
        guard let model = try await EffectiveLengthModel.find(id, on: database) else {
          throw NotFoundError()
        }
        return try await updatePath(on: database, baseline: model.toDTO(), updates: updates)
      }
    )
  }
}

extension EquivalentLength.Create {

  func toModel() throws -> EffectiveLengthModel {
    if groups.count > 0 {
      try [EquivalentLength.FittingGroup].validator().validate(groups)
    }
    return try .init(
      name: name,
      type: type.rawValue,
      straightLengths: straightLengths,
      groups: JSONEncoder().encode(groups),
      projectID: projectID,
      templateSnapshot: templateSnapshot.map { try JSONEncoder().encode($0) }
    )
  }
}

extension EquivalentLength {

  struct Migrate: AsyncMigration {
    let name = "CreateEffectiveLength"

    func prepare(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema)
        .id()
        .field("name", .string, .required)
        .field("type", .string, .required)
        .field("straightLengths", .array(of: .int))
        .field("groups", .data)
        .field("createdAt", .string)
        .field("updatedAt", .string)
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

  @OptionalField(key: "revision")
  var revision: UUID?

  @OptionalField(key: "templateSnapshot")
  var templateSnapshot: Data?

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
    projectID: Project.ID,
    templateSnapshot: Data? = nil
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.straightLengths = straightLengths
    self.groups = groups
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    $project.id = projectID
    self.templateSnapshot = templateSnapshot
  }

  func toDTO() throws -> EquivalentLength {
    try .init(
      id: requireID(),
      projectID: $project.id,
      name: name,
      type: .init(rawValue: type)!,
      straightLengths: straightLengths,
      groups: JSONDecoder().decode([EquivalentLength.FittingGroup].self, from: groups),
      createdAt: createdAt!,
      updatedAt: updatedAt!,
      templateSnapshot: templateSnapshot.map {
        try JSONDecoder().decode(PathTemplate.Snapshot.self, from: $0)
      },
      revision: revision
    )
  }

  func applyUpdates(_ updates: EquivalentLength.Update) throws {
    if let snapshot = updates.templateSnapshot {
      templateSnapshot = try JSONEncoder().encode(snapshot)
    }
    if let name = updates.name, name != self.name {
      self.name = name
    }
    if let type = updates.type, type.rawValue != self.type {
      self.type = type.rawValue
    }
    if let straightLengths = updates.straightLengths, straightLengths != self.straightLengths {
      self.straightLengths = straightLengths
    }
    if let groups = updates.groups {
      if groups.count > 0 {
        try [EquivalentLength.FittingGroup].validator().validate(groups)
      }
      self.groups = try JSONEncoder().encode(groups)
    }
  }
}

extension EffectiveLengthModel: Validatable {

  var body: some Validation<EffectiveLengthModel> {
    Validator.accumulating {
      Validator.validate(\.name, with: .notEmpty())
        .errorLabel("Name", inline: true)

      Validator.validate(
        \.straightLengths,
        with: [Int].empty().or(
          ForEachValidator {
            Int.greaterThan(0)
          })
      )
      .errorLabel("Straight Lengths", inline: true)
    }
  }
}

extension EquivalentLength.FittingGroup: Validatable {

  public var body: some Validation<Self> {
    Validator.accumulating {
      Validator.validate(\.group) {
        Int.greaterThanOrEquals(1)
        Int.lessThanOrEquals(12)
      }
      .errorLabel("Group", inline: true)

      if fitting?.origin != .legacy && !(group == 11 && fitting?.origin == .catalog) {
        Validator.validate(\.letter, with: .regex(matching: "^[a-zA-Z]+$"))
          .errorLabel("Letter", inline: true)
      }

      Validator.validate(\.value, with: .greaterThanOrEquals(0))
        .errorLabel("Value", inline: true)

      Validator.validate(\.quantity, with: .greaterThanOrEquals(1))
        .errorLabel("Quantity", inline: true)
    }
  }
}
extension EquivalentLength {
  struct AddTemplateSnapshot: AsyncMigration {
    let name = "AddEffectiveLengthTemplateSnapshot"
    func prepare(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema)
        .field("templateSnapshot", .data).update()
    }
    func revert(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema)
        .deleteField("templateSnapshot").update()
    }
  }
}

public struct PathConflictError: Error, Sendable {
  public init() {}
  public var message: String {
    "This path changed in another tab. Your draft is still here. Reload the saved path before trying again."
  }
}

extension EquivalentLength {
  struct AddRevision: AsyncMigration {
    let name = "AddEffectiveLengthRevision"
    func prepare(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema).field("revision", .uuid).update()
    }
    func revert(on database: any Database) async throws {
      try await database.schema(EffectiveLengthModel.schema).deleteField("revision").update()
    }
  }
}

private func updatePath(
  on database: any Database, baseline: EquivalentLength, updates: EquivalentLength.Update
) async throws -> EquivalentLength {
  let revision = UUID()
  return try await database.transaction { transaction in
    // Claim this revision atomically. The row stays locked through validation and saving.
    try await EffectiveLengthModel.query(on: transaction)
      .filter(\.$id == baseline.id)
      .filter(\.$project.$id == baseline.projectID)
      .filter(\.$revision == baseline.revision)
      .set(\.$revision, to: revision)
      .update()
    guard let model = try await EffectiveLengthModel.find(baseline.id, on: transaction),
      model.revision == revision
    else { throw PathConflictError() }
    try model.applyUpdates(updates)
    try await model.validateAndSave(on: transaction)
    return try model.toDTO()
  }
}
