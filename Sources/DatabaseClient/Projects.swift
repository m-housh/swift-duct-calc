import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
  @DependencyClient
  public struct Projects: Sendable {
    public var create: @Sendable (Project.Create) async throws -> Project
    public var delete: @Sendable (Project.ID) async throws -> Void
    public var get: @Sendable (Project.ID) async throws -> Project?
  }
}

extension DatabaseClient.Projects: TestDependencyKey {
  public static let testValue = Self()
}

extension DatabaseClient.Projects {
  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = try request.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = ProjectModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      get: { id in
        ProjectModel.find(id, on: database).map { try $0.toDTO() }
      }
    )
  }
}

extension Project.Create {

  func toModel() throws -> ProjectModel {
    try validate()
    return .init(
      name: name,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode
    )
  }

  func validate() throws(ValidationError) {
    guard !name.isEmpty else {
      throw ValidationError("Project name should not be empty.")
    }
    guard !streetAddress.isEmpty else {
      throw ValidationError("Project street address should not be empty.")
    }
    guard !city.isEmpty else {
      throw ValidationError("Project city should not be empty.")
    }
    guard !state.isEmpty else {
      throw ValidationError("Project state should not be empty.")
    }
    guard !zipCode.isEmpty else {
      throw ValidationError("Project zipCode should not be empty.")
    }
  }
}

extension Project {
  struct Migrate: AsyncMigration {
    let name = "CreateProject"

    func prepare(on database: any Database) async throws {
      try await database.schema(ProjectModel.schema)
        .id()
        .field("name", .string, .required)
        .field("streetAddress", .string, .required)
        .field("city", .string, .required)
        .field("state", .string, .required)
        .field("zipCode", .string, .required)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .unique(on: "name")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(ProjectModel.schema).delete()
    }
  }
}

// The Database model.
final class ProjectModel: Model, @unchecked Sendable {

  static let schema = "project"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "name")
  var name: String

  @Field(key: "streetAddress")
  var streetAddress: String

  @Field(key: "city")
  var city: String

  @Field(key: "state")
  var state: String

  @Field(key: "zipCode")
  var zipCode: String

  @Timestamp(key: "createdAt", on: .create, format: .iso8601)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
  var updatedAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    name: String,
    streetAddress: String,
    city: String,
    state: String,
    zipCode: String,
    createdAt: Date? = nil,
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.streetAddress = streetAddress
    self.city = city
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  func toDTO() throws -> Project {
    try .init(
      id: requireID(),
      name: name,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }
}
