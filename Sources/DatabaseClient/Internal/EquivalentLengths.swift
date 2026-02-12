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
      create: { request in
        let model = try request.toModel()
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
        try model.applyUpdates(updates)
        if model.hasChanges {
          try await model.validateAndSave(on: database)
        }
        return try model.toDTO()
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
      projectID: projectID
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

  func toDTO() throws -> EquivalentLength {
    try .init(
      id: requireID(),
      projectID: $project.id,
      name: name,
      type: .init(rawValue: type)!,
      straightLengths: straightLengths,
      groups: JSONDecoder().decode([EquivalentLength.FittingGroup].self, from: groups),
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: EquivalentLength.Update) throws {
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

      Validator.validate(\.letter, with: .regex(matching: "[a-zA-Z]"))
        .errorLabel("Letter", inline: true)

      Validator.validate(\.value, with: .greaterThan(0))
        .errorLabel("Value", inline: true)

      Validator.validate(\.quantity, with: .greaterThanOrEquals(1))
        .errorLabel("Quantity", inline: true)
    }
  }
}
