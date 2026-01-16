import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient {
  @DependencyClient
  public struct Projects: Sendable {
    public var create: @Sendable (User.ID, Project.Create) async throws -> Project
    public var delete: @Sendable (Project.ID) async throws -> Void
    public var get: @Sendable (Project.ID) async throws -> Project?
    public var getCompletedSteps: @Sendable (Project.ID) async throws -> Project.CompletedSteps
    public var getSensibleHeatRatio: @Sendable (Project.ID) async throws -> Double?
    public var fetch: @Sendable (User.ID, PageRequest) async throws -> Page<Project>
    public var update: @Sendable (Project.ID, Project.Update) async throws -> Project
  }
}

extension DatabaseClient.Projects: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { userID, request in
        let model = try request.toModel(userID: userID)
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await ProjectModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      get: { id in
        try await ProjectModel.find(id, on: database).map { try $0.toDTO() }
      },
      getCompletedSteps: { id in
        let roomsCount = try await RoomModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id == id)
          .count()

        let equivalentLengths = try await EffectiveLengthModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id == id)
          .all()

        var equivalentLengthsCompleted = false

        if equivalentLengths.filter({ $0.type == "supply" }).first != nil,
          equivalentLengths.filter({ $0.type == "return" }).first != nil
        {
          equivalentLengthsCompleted = true
        }

        let componentLosses = try await ComponentLossModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id == id)
          .count()

        let equipmentInfo = try await EquipmentModel.query(on: database)
          .with(\.$project)
          .filter(\.$project.$id == id)
          .first()

        return .init(
          equipmentInfo: equipmentInfo != nil,
          rooms: roomsCount > 0,
          equivalentLength: equivalentLengthsCompleted,
          frictionRate: componentLosses > 0
        )
      },
      getSensibleHeatRatio: { id in
        guard
          let shr = try await ProjectModel.query(on: database)
            .field(\.$id)
            .field(\.$sensibleHeatRatio)
            .filter(\.$id == id)
            .first()
        else {
          throw NotFoundError()
        }
        return shr.sensibleHeatRatio
      },
      fetch: { userID, request in
        try await ProjectModel.query(on: database)
          .sort(\.$createdAt, .descending)
          .with(\.$user)
          .filter(\.$user.$id == userID)
          .paginate(request)
          .map { try $0.toDTO() }
      },
      update: { id, updates in
        guard let model = try await ProjectModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try updates.validate()
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.save(on: database)
        }
        return try model.toDTO()
      }
    )
  }
}

extension Project.Create {

  func toModel(userID: User.ID) throws -> ProjectModel {
    try validate()
    return .init(
      name: name,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode,
      userID: userID
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
    if let sensibleHeatRatio {
      guard sensibleHeatRatio >= 0 else {
        throw ValidationError("Project sensible heat ratio should be greater than 0.")
      }
      guard sensibleHeatRatio <= 1 else {
        throw ValidationError("Project sensible heat ratio should be less than 1.")
      }
    }
  }
}

extension Project.Update {

  func validate() throws(ValidationError) {
    if let name {
      guard !name.isEmpty else {
        throw ValidationError("Project name should not be empty.")
      }
    }
    if let streetAddress {
      guard !streetAddress.isEmpty else {
        throw ValidationError("Project street address should not be empty.")
      }
    }
    if let city {
      guard !city.isEmpty else {
        throw ValidationError("Project city should not be empty.")
      }
    }
    if let state {
      guard !state.isEmpty else {
        throw ValidationError("Project state should not be empty.")
      }
    }
    if let zipCode {
      guard !zipCode.isEmpty else {
        throw ValidationError("Project zipCode should not be empty.")
      }
    }
    if let sensibleHeatRatio {
      guard sensibleHeatRatio >= 0 else {
        throw ValidationError("Project sensible heat ratio should be greater than 0.")
      }
      guard sensibleHeatRatio <= 1 else {
        throw ValidationError("Project sensible heat ratio should be less than 1.")
      }
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
        .field("sensibleHeatRatio", .double)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .field("userID", .uuid, .required, .references(UserModel.schema, "id"))
        .unique(on: "userID", "name")
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

  @Field(key: "sensibleHeatRatio")
  var sensibleHeatRatio: Double?

  @Timestamp(key: "createdAt", on: .create, format: .iso8601)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
  var updatedAt: Date?

  @Children(for: \.$project)
  var componentLosses: [ComponentLossModel]

  @Parent(key: "userID")
  var user: UserModel

  init() {}

  init(
    id: UUID? = nil,
    name: String,
    streetAddress: String,
    city: String,
    state: String,
    zipCode: String,
    sensibleHeatRatio: Double? = nil,
    userID: User.ID,
    createdAt: Date? = nil,
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.streetAddress = streetAddress
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.sensibleHeatRatio = sensibleHeatRatio
    $user.id = userID
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
      sensibleHeatRatio: sensibleHeatRatio,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: Project.Update) {
    if let name = updates.name, name != self.name {
      self.name = name
    }
    if let streetAddress = updates.streetAddress, streetAddress != self.streetAddress {
      self.streetAddress = streetAddress
    }
    if let city = updates.city, city != self.city {
      self.city = city
    }
    if let state = updates.state, state != self.state {
      self.state = state
    }
    if let zipCode = updates.zipCode, zipCode != self.zipCode {
      self.zipCode = zipCode
    }
    if let sensibleHeatRatio = updates.sensibleHeatRatio,
      sensibleHeatRatio != self.sensibleHeatRatio
    {
      self.sensibleHeatRatio = sensibleHeatRatio
    }
  }
}
