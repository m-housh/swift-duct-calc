import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
  @DependencyClient
  public struct Equipment: Sendable {
    public var create: @Sendable (EquipmentInfo.Create) async throws -> EquipmentInfo
    public var delete: @Sendable (EquipmentInfo.ID) async throws -> Void
    public var fetch: @Sendable (Project.ID) async throws -> EquipmentInfo?
    public var get: @Sendable (EquipmentInfo.ID) async throws -> EquipmentInfo?
    public var update: @Sendable (EquipmentInfo.Update) async throws -> EquipmentInfo
  }
}

extension DatabaseClient.Equipment: TestDependencyKey {
  public static let testValue = Self()
}

extension DatabaseClient.Equipment {
  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = try request.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await EquipmentModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      fetch: { projectId in
        guard
          let model = try await EquipmentModel.query(on: database)
            .filter("projectID", .equal, projectId)
            .first()
        else {
          return nil
        }
        return try model.toDTO()
      },
      get: { id in
        try await EquipmentModel.find(id, on: database).map { try $0.toDTO() }
      },
      update: { request in
        guard let model = try await EquipmentModel.find(request.id, on: database) else {
          throw NotFoundError()
        }
        guard request.hasUpdates else { return try model.toDTO() }
        try model.applyUpdates(request)
        try await model.save(on: database)
        return try model.toDTO()
      }
    )
  }
}

extension EquipmentInfo.Create {

  func toModel() throws(ValidationError) -> EquipmentModel {
    try validate()
    return .init(
      staticPressure: staticPressure,
      heatingCFM: heatingCFM,
      coolingCFM: coolingCFM,
      projectID: projectID
    )
  }

  func validate() throws(ValidationError) {
    guard staticPressure >= 0 else {
      throw ValidationError("Equipment info static pressure should be greater than 0.")
    }
    guard staticPressure <= 1.0 else {
      throw ValidationError("Equipment info static pressure should be less than 1.0.")
    }
    guard heatingCFM >= 0 else {
      throw ValidationError("Equipment info heating CFM should be greater than 0.")
    }
    guard coolingCFM >= 0 else {
      throw ValidationError("Equipment info heating CFM should be greater than 0.")
    }
  }
}

extension EquipmentInfo.Update {
  var hasUpdates: Bool {
    staticPressure != nil || heatingCFM != nil || coolingCFM != nil
  }

  func validate() throws(ValidationError) {
    if let staticPressure {
      guard staticPressure >= 0 else {
        throw ValidationError("Equipment info static pressure should be greater than 0.")
      }
    }
    if let heatingCFM {
      guard heatingCFM >= 0 else {
        throw ValidationError("Equipment info heating CFM should be greater than 0.")
      }
    }
    if let coolingCFM {
      guard coolingCFM >= 0 else {
        throw ValidationError("Equipment info heating CFM should be greater than 0.")
      }
    }
  }
}

extension EquipmentInfo {

  struct Migrate: AsyncMigration {

    let name = "CreateEquipment"

    func prepare(on database: any Database) async throws {
      try await database.schema(EquipmentModel.schema)
        .id()
        .field("staticPressure", .double, .required)
        .field("heatingCFM", .int16, .required)
        .field("coolingCFM", .int16, .required)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .field("projectID", .uuid, .required, .references(ProjectModel.schema, "id"))
        .unique(on: "projectID")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(EquipmentModel.schema).delete()
    }

  }
}

final class EquipmentModel: Model, @unchecked Sendable {

  static let schema = "equipment"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "staticPressure")
  var staticPressure: Double

  @Field(key: "heatingCFM")
  var heatingCFM: Int

  @Field(key: "coolingCFM")
  var coolingCFM: Int

  @Timestamp(key: "createdAt", on: .create, format: .iso8601)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
  var updatedAt: Date?

  @Parent(key: "projectID")
  var project: ProjectModel

  init() {}

  init(
    id: UUID? = nil,
    staticPressure: Double,
    heatingCFM: Int,
    coolingCFM: Int,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    projectID: Project.ID
  ) {
    self.id = id
    self.staticPressure = staticPressure
    self.heatingCFM = heatingCFM
    self.coolingCFM = coolingCFM
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    $project.id = projectID
  }

  func toDTO() throws -> EquipmentInfo {
    try .init(
      id: requireID(),
      projectID: $project.id,
      staticPressure: staticPressure,
      heatingCFM: heatingCFM,
      coolingCFM: coolingCFM,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: EquipmentInfo.Update) throws {
    try updates.validate()
    if let staticPressure = updates.staticPressure {
      self.staticPressure = staticPressure
    }
    if let heatingCFM = updates.heatingCFM {
      self.heatingCFM = heatingCFM
    }
    if let coolingCFM = updates.coolingCFM {
      self.coolingCFM = coolingCFM
    }
  }
}
