import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import SQLKit
import Validations

extension DatabaseClient.Projects: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      recent: { userID in
        let opened = try await ProjectModel.query(on: database)
          .filter(\.$user.$id == userID).filter(\.$lastOpenedAt != nil)
          .sort(\.$lastOpenedAt, .descending).sort(\.$id).limit(5).all()
        let fallback = try await ProjectModel.query(on: database)
          .filter(\.$user.$id == userID).filter(\.$lastOpenedAt == nil)
          .sort(\.$createdAt, .descending).sort(\.$id).limit(5).all()
        return try Array((opened + fallback).prefix(5)).map { try $0.toDTO() }
      },
      recordOpen: { projectID, userID, date in
        // QueryBuilder.update also advances updatedAt. Opening a project is not a design edit.
        guard let sql = database as? any SQLDatabase else { throw NotFoundError() }
        try await sql.raw(
          """
          UPDATE \(ident: ProjectModel.schema) SET \(ident: "lastOpenedAt") = \(bind: date.timeIntervalSince1970)
          WHERE \(ident: "id") = \(bind: projectID) AND \(ident: "userID") = \(bind: userID)
          """
        ).run()
      },
      search: { userID, search, page in
        let query = ProjectModel.query(on: database).filter(\.$user.$id == userID)
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
          // Match literal text consistently on both SQLite and PostgreSQL.
          let pattern =
            "%"
            + term.lowercased()
            .replacingOccurrences(of: "!", with: "!!")
            .replacingOccurrences(of: "%", with: "!%")
            .replacingOccurrences(of: "_", with: "!_") + "%"
          query.filter(
            .custom(
              SQLQueryString(
                """
                (LOWER(\(ident: "name")) LIKE \(bind: pattern) ESCAPE '!'
                OR LOWER(\(ident: "streetAddress")) LIKE \(bind: pattern) ESCAPE '!'
                OR LOWER(\(ident: "city")) LIKE \(bind: pattern) ESCAPE '!')
                """)))
        }
        return try await query.sort(\.$createdAt, .descending).sort(\.$id)
          .paginate(page).map { try $0.toDTO() }
      },
      importPDF: { userID, report, confirmDuplicate in
        try await database.transaction { transaction in
          guard !report.rooms.isEmpty else {
            throw RoomImportError("No room loads were found to import.")
          }
          guard let shr = report.project.sensibleHeatRatio, shr.isFinite, shr > 0, shr <= 1 else {
            throw RoomImportError("The report has no valid sensible heat ratio.")
          }
          let model = report.project.toModel(userID: userID)
          model.sensibleHeatRatio = shr
          // A project import always creates a new project; keep existing projects intact.
          let existing = try await ProjectModel.query(on: transaction)
            .filter(\.$user.$id == userID).all()
          func normalized(_ value: String) -> String {
            value.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
          }
          let matches = existing.filter {
            normalized($0.name) == normalized(report.project.name)
              || (normalized($0.streetAddress) == normalized(report.project.streetAddress)
                && normalized($0.zipCode).prefix(5) == normalized(report.project.zipCode).prefix(5))
          }
          if !confirmDuplicate && !matches.isEmpty {
            throw Project.ImportConflict(projects: try matches.map { try $0.toDTO() })
          }
          let names = Set(existing.map { normalized($0.name) })
          var suffix = 2
          while names.contains(normalized(model.name)) {
            model.name = "\(report.project.name) (\(suffix))"
            suffix += 1
          }
          try await model.validateAndSave(on: transaction)
          let projectID = try model.requireID()
          var roomNames = Set<String>()
          for room in report.rooms {
            guard
              roomNames.insert(
                room.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
              ).inserted
            else {
              throw RoomImportError("The report contains repeated room names.")
            }
            let roomModel = RoomModel(
              name: room.name, level: room.level?.rawValue, heatingLoad: room.heatingLoad,
              coolingLoad: .init(total: room.coolingTotal, sensible: room.coolingSensible),
              registerCount: 1, projectID: projectID)
            try await roomModel.validateAndSave(on: transaction)
          }
          for loss in ComponentPressureLoss.Create.default(projectID: projectID) {
            try await loss.toModel().validateAndSave(on: transaction)
          }
          return try model.toDTO()
        }
      },
      create: { userID, request in
        let model = request.toModel(userID: userID)
        try await model.validateAndSave(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await ProjectModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      detail: { id in
        guard let model = try await ProjectModel.fetchDetail(for: id, on: database) else {
          return nil
        }

        let trunks = try model.trunks.toDTO()

        return try .init(
          project: model.toDTO(),
          componentLosses: model.componentLosses.map { try $0.toDTO() },
          equipmentInfo: model.equipment?.toDTO(),
          equivalentLengths: model.equivalentLengths.map { try $0.toDTO() },
          rooms: model.rooms.map { try $0.toDTO() },
          trunks: trunks
        )
      },
      get: { id in
        try await ProjectModel.find(id, on: database).map { try $0.toDTO() }
      },
      getForUser: { projectID, userID in
        try await ProjectModel.query(on: database).filter(\.$id == projectID)
          .filter(\.$user.$id == userID).first().map { try $0.toDTO() }
      },
      getCompletedSteps: { id in
        guard let model = try await ProjectModel.fetchDetail(for: id, on: database) else {
          throw NotFoundError()
        }
        var equivalentLengthsCompleted = false

        if model.equivalentLengths.filter({ $0.type == "supply" }).first != nil,
          model.equivalentLengths.filter({ $0.type == "return" }).first != nil
        {
          equivalentLengthsCompleted = true
        }

        return .init(
          equipmentInfo: model.equipment != nil,
          rooms: model.rooms.count > 0,
          equivalentLength: equivalentLengthsCompleted,
          frictionRate: model.componentLosses.count > 0
        )
      },
      getSensibleHeatRatio: { id in
        guard
          let model = try await ProjectModel.query(on: database)
            .field(\.$id)
            .field(\.$sensibleHeatRatio)
            .filter(\.$id == id)
            .first()
        else {
          throw NotFoundError()
        }
        return model.sensibleHeatRatio
      },
      fetch: { userID, request in
        try await ProjectModel.query(on: database)
          .sort(\.$createdAt, .descending).sort(\.$id)
          .with(\.$user)
          .filter(\.$user.$id == userID)
          .paginate(request)
          .map { try $0.toDTO() }
      },
      update: { id, updates in
        guard let model = try await ProjectModel.find(id, on: database) else {
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

extension Project.Create {

  func toModel(userID: User.ID) -> ProjectModel {
    return .init(
      name: name,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode,
      userID: userID
    )
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
        .field("createdAt", .string)
        .field("updatedAt", .string)
        .field("userID", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
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

  @OptionalField(key: "lastOpenedAt")
  var lastOpenedAt: Double?

  @Children(for: \.$project)
  var componentLosses: [ComponentLossModel]

  @OptionalChild(for: \.$project)
  var equipment: EquipmentModel?

  @Children(for: \.$project)
  var equivalentLengths: [EffectiveLengthModel]

  @Children(for: \.$project)
  var rooms: [RoomModel]

  @Children(for: \.$project)
  var trunks: [TrunkModel]

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

  /// Returns a ``ProjectModel`` with all the relations eagerly loaded.
  static func fetchDetail(
    for projectID: Project.ID,
    on database: any Database
  ) async throws -> ProjectModel? {
    try await ProjectModel.query(on: database)
      .with(\.$componentLosses)
      .with(\.$equipment)
      .with(\.$equivalentLengths)
      .with(\.$rooms)
      .with(
        \.$trunks,
        { trunk in
          trunk.with(
            \.$rooms,
            {
              $0.with(\.$room)
            }
          )
        }
      )
      .filter(\.$id == projectID)
      .first()
  }
}

extension ProjectModel: Validatable {

  var body: some Validation<ProjectModel> {
    Validator.accumulating {
      Validator.validate(\.name, with: .notEmpty())
        .errorLabel("Name", inline: true)

      Validator.validate(\.streetAddress, with: .notEmpty())
        .errorLabel("Address", inline: true)

      Validator.validate(\.city, with: .notEmpty())
        .errorLabel("City", inline: true)

      Validator.validate(\.state, with: .notEmpty())
        .errorLabel("State", inline: true)

      Validator.validate(\.zipCode, with: .notEmpty())
        .errorLabel("Zip", inline: true)

      Validator.validate(\.sensibleHeatRatio) {
        Validator {
          Double.greaterThan(0)
          Double.lessThanOrEquals(1.0)
        }
        .optional()
      }
      .errorLabel("Sensible Heat Ratio", inline: true)

    }
  }
}

extension Project {
  struct AddLastOpenedAt: AsyncMigration {
    func prepare(on database: any Database) async throws {
      try await database.schema(ProjectModel.schema).field("lastOpenedAt", .double).update()
    }
    func revert(on database: any Database) async throws {
      try await database.schema(ProjectModel.schema).deleteField("lastOpenedAt").update()
    }
  }
}
