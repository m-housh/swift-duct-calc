import Dependencies
import Fluent
import Foundation
import ManualDCore

extension DatabaseClient.Filters {
  static func live(database: any Database) -> Self {
    .init(
      fetch: { userID in try await loadFilters(userID, on: database).library },
      update: { userID, change in
        @Dependency(\.uuid) var uuid
        let newID = uuid().uuidString
        let revision = uuid()
        return try await database.transaction { db in
          // Serializes first writes too, before an account has a library row.
          guard try await UserModel.find(userID, on: db) != nil else { throw NotFoundError() }
          try await UserModel.query(on: db).filter(\.$id == userID).set(\.$id, to: userID).update()
          let (model, saved) = try await loadFilters(userID, on: db)
          var library = saved
          try library.apply(change, newID: newID, revision: revision)
          let row = model ?? FilterLibraryModel()
          row.userID = userID
          row.document = String(decoding: try JSONEncoder().encode(library), as: UTF8.self)
          try await row.save(on: db)
          return library
        }
      },
      allowance: { projectID in
        try await ProjectFilterModel.query(on: database).filter(\.$projectID == projectID).first()?
          .allowance
      },
      apply: { userID, projectID, selection in
        let allowance = try selection.validatedAllowance()
        try await database.transaction { db in
          guard let project = try await ProjectModel.find(projectID, on: db),
            project.$user.id == userID
          else { throw NotFoundError() }
          try await ProjectModel.query(on: db).filter(\.$id == projectID).set(\.$id, to: projectID)
            .update()
          let library = try await loadFilters(userID, on: db).library
          guard let filter = library.filters.first(where: { $0.id == selection.model }) else {
            throw NotFoundError()
          }
          guard
            let airflow = try await DatabaseClient.Equipment.live(database: db).fetch(projectID)?
              .largerAirflow
          else {
            throw FilterError("Enter heating or cooling airflow in Equipment to look up a filter.")
          }
          let losses = DatabaseClient.ComponentLosses.live(database: db)
          if let id = selection.replacing {
            guard try await losses.get(id)?.projectID == projectID else { throw NotFoundError() }
          }
          let value = filter.additionalPressureDrop(at: airflow, allowance: allowance)
          guard value <= 1 else {
            throw FilterError(
              "The filter loss exceeds 1.00 in. w.c. Choose a filter rated for this airflow.")
          }
          var name = "\(filter.name) filter"
          if let allowance { name += String(format: " (less %.2f in equipment rating)", allowance) }
          if value == 0 {
            if let id = selection.replacing { try await losses.delete(id) }
          } else if let id = selection.replacing {
            _ = try await losses.update(id, .init(name: name, value: value))
          } else {
            _ = try await losses.create(.init(projectID: projectID, name: name, value: value))
          }
          let settings =
            try await ProjectFilterModel.query(on: db).filter(\.$projectID == projectID).first()
            ?? ProjectFilterModel()
          settings.projectID = projectID
          settings.allowance = allowance
          try await settings.save(on: db)
        }
      })
  }
}

private func loadFilters(_ userID: User.ID, on db: any Database) async throws -> (
  model: FilterLibraryModel?, library: FilterLibrary
) {
  let row = try await FilterLibraryModel.query(on: db).filter(\.$userID == userID).first()
  let library =
    try row.map { try JSONDecoder().decode(FilterLibrary.self, from: Data($0.document.utf8)) }
    ?? FilterLibrary()
  return (row, library)
}

private final class FilterLibraryModel: Model, @unchecked Sendable {
  static let schema = "filter_library"
  @ID(key: .id) var id: UUID?
  @Field(key: "userID") var userID: UUID
  @Field(key: "document") var document: String
  init() {}
}
private final class ProjectFilterModel: Model, @unchecked Sendable {
  static let schema = "project_filter_settings"
  @ID(key: .id) var id: UUID?
  @Field(key: "projectID") var projectID: UUID
  @OptionalField(key: "allowance") var allowance: Double?
  init() {}
}
struct FilterLibraryMigration: AsyncMigration {
  func prepare(on db: any Database) async throws {
    try await db.schema(FilterLibraryModel.schema).id()
      .field("userID", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
      .field("document", .string, .required).unique(on: "userID").create()
    try await db.schema(ProjectFilterModel.schema).id()
      .field(
        "projectID", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade)
      )
      .field("allowance", .double).unique(on: "projectID").create()
  }
  func revert(on db: any Database) async throws {
    try await db.schema(ProjectFilterModel.schema).delete()
    try await db.schema(FilterLibraryModel.schema).delete()
  }
}
