import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import Validations

extension DatabaseClient.Equipment: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        let model = request.toModel()
        try await model.validateAndSave(on: database)
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
      update: { id, updates in
        guard let model = try await EquipmentModel.find(id, on: database) else {
          throw NotFoundError()
        }
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.validateAndSave(on: database)
        }
        return try model.toDTO()
      }
    )
  }
}

extension EquipmentInfo.Create {

  func toModel() -> EquipmentModel {
    return .init(
      staticPressure: staticPressure,
      heatingCFM: heatingCFM,
      coolingCFM: coolingCFM,
      projectID: projectID
    )
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
        .field("createdAt", .string)
        .field("updatedAt", .string)
        .field(
          "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
        )
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

  func applyUpdates(_ updates: EquipmentInfo.Update) {
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

extension EquipmentModel: Validatable {

  var body: some Validation<EquipmentModel> {
    Validator.accumulating {
      Validator.validate(\.staticPressure) {
        Double.greaterThan(0.0)
        Double.lessThan(1.0)
      }
      .errorLabel("Static Pressure", inline: true)

      Validator.validate(\.heatingCFM, with: .greaterThan(0))
        .errorLabel("Heating CFM", inline: true)

      Validator.validate(\.coolingCFM, with: .greaterThan(0))
        .errorLabel("Cooling CFM", inline: true)
    }
  }
}
