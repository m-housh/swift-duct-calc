import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import SQLKit

extension DatabaseClient.ComponentLosses: TestDependencyKey {
  public static let testValue = Self()
}

extension DatabaseClient.ComponentLosses {
  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = try request.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await ComponentLossModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      fetch: { projectID in
        try await ComponentLossModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id, .equal, projectID)
          .all()
          .map { try $0.toDTO() }

      },
      get: { id in
        try await ComponentLossModel.find(id, on: database).map { try $0.toDTO() }
      },
      update: { id, updates in
        try updates.validate()
        guard let model = try await ComponentLossModel.find(id, on: database) else {
          throw NotFoundError()
        }
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.save(on: database)
        }
        return try model.toDTO()
      }
    )
  }
}

extension ComponentPressureLoss.Create {

  func toModel() throws(ValidationError) -> ComponentLossModel {
    try validate()
    return .init(name: name, value: value, projectID: projectID)
  }

  func validate() throws(ValidationError) {
    guard !name.isEmpty else {
      throw ValidationError("Component loss name should not be empty.")
    }
    guard value > 0 else {
      throw ValidationError("Component loss value should be greater than 0.")
    }
    guard value < 1.0 else {
      throw ValidationError("Component loss value should be less than 1.0.")
    }
  }
}

extension ComponentPressureLoss.Update {
  func validate() throws(ValidationError) {
    if let name {
      guard !name.isEmpty else {
        throw ValidationError("Component loss name should not be empty.")
      }
    }
    if let value {
      guard value > 0 else {
        throw ValidationError("Component loss value should be greater than 0.")
      }
      guard value < 1.0 else {
        throw ValidationError("Component loss value should be less than 1.0.")
      }
    }
  }
}

extension ComponentPressureLoss {
  struct Migrate: AsyncMigration {
    let name = "CreateComponentLoss"

    func prepare(on database: any Database) async throws {
      try await database.schema(ComponentLossModel.schema)
        .id()
        .field("name", .string, .required)
        .field("value", .double, .required)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .field(
          "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
        )
        // .unique(on: "projectID", "name")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(ComponentLossModel.schema).delete()
    }
  }
}

final class ComponentLossModel: Model, @unchecked Sendable {

  static let schema = "component_loss"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "name")
  var name: String

  @Field(key: "value")
  var value: Double

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
    value: Double,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.name = name
    self.value = value
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    $project.id = projectID
  }

  func toDTO() throws -> ComponentPressureLoss {
    try .init(
      id: requireID(),
      projectID: $project.id,
      name: name,
      value: value,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: ComponentPressureLoss.Update) {
    if let name = updates.name, name != self.name {
      self.name = name
    }
    if let value = updates.value, value != self.value {
      self.value = value
    }
  }
}
