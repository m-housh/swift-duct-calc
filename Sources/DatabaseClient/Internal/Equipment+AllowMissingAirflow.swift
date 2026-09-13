import Fluent
import ManualDCore
import SQLKit

extension EquipmentInfo {
  struct AllowMissingAirflow: AsyncMigration {
    func prepare(on database: any Database) async throws {
      try await rebuild(on: database, required: false)
    }

    func revert(on database: any Database) async throws {
      // Refuse to discard drafts when restoring the original NOT NULL constraints.
      try await rebuild(on: database, required: true)
    }

    private func rebuild(on database: any Database, required: Bool) async throws {
      // SQLite cannot drop NOT NULL constraints in place. Equipment has no incoming
      // foreign keys, so rebuilding also works on PostgreSQL without changing its IDs.
      try await database.transaction { transaction in
        guard let sql = transaction as? any SQLDatabase else {
          throw ValidationError("Equipment migration requires an SQL database.")
        }
        if sql.dialect.name == "postgresql" {
          // A second app instance must not write between the copy and the rename.
          try await sql.raw("LOCK TABLE \(ident: EquipmentModel.schema) IN ACCESS EXCLUSIVE MODE")
            .run()
        }
        let table = required ? "equipment_required_migration" : "equipment_airflow_migration"
        let schema = transaction.schema(table)
          .id()
          .field("staticPressure", .double, .required)
          .field("createdAt", .string)
          .field("updatedAt", .string)
          .field(
            "projectID", .uuid, .required,
            .references(ProjectModel.schema, "id", onDelete: .cascade)
          )
          .unique(on: "projectID")
        if required {
          schema.field("heatingCFM", .int16, .required).field("coolingCFM", .int16, .required)
        } else {
          schema.field("heatingCFM", .int16).field("coolingCFM", .int16)
        }
        try await schema.create()
        try await sql.raw(
          """
          INSERT INTO \(ident: table)
            ("id", "staticPressure", "heatingCFM", "coolingCFM", "createdAt", "updatedAt", "projectID")
          SELECT "id", "staticPressure", "heatingCFM", "coolingCFM", "createdAt", "updatedAt", "projectID"
          FROM \(ident: EquipmentModel.schema)
          """
        ).run()
        try await transaction.schema(EquipmentModel.schema).delete()
        try await sql.raw("ALTER TABLE \(ident: table) RENAME TO \(ident: EquipmentModel.schema)")
          .run()
      }
    }
  }
}
