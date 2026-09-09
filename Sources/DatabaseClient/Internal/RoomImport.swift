import Fluent
import Foundation
import ManualDCore
import Validations

extension RoomModel {
  /// Updates in place so trunk assignments and airflow delegation keep referencing the same rooms.
  static func importRows(
    projectID: Project.ID,
    userID: User.ID,
    rows: [Room.CSV.Row],
    reportSHR: Double?,
    updateDistribution: Bool,
    on database: any Database
  ) async throws -> [Room] {
    try await database.transaction { transaction in
      guard let project = try await ProjectModel.find(projectID, on: transaction),
        project.$user.id == userID
      else { throw NotFoundError() }
      guard !rows.isEmpty else { throw RoomImportError("No room loads were found to import.") }

      func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      }

      let existing = try await RoomModel.query(on: transaction)
        .filter(\.$project.$id, .equal, projectID).all()
      var byName: [String: RoomModel] = [:]
      for model in existing {
        guard byName.updateValue(model, forKey: key(model.name)) == nil else {
          throw RoomImportError(
            "Multiple existing rooms have the same name. Give them distinct names before importing."
          )
        }
      }

      var importedNames = Set<String>()
      var imported: [RoomModel] = []
      for row in rows {
        let name = key(row.name)
        guard !name.isEmpty, importedNames.insert(name).inserted else {
          throw RoomImportError(
            "The file contains an empty or repeated room name. No rooms were changed.")
        }
        let model: RoomModel
        if let match = byName[name] {
          model = match
          model.level = row.level?.rawValue
          model.heatingLoad = row.heatingLoad
          model.coolingLoad = .init(total: row.coolingTotal, sensible: row.coolingSensible)
        } else {
          model = RoomModel(
            id: UUID(), name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
            level: row.level?.rawValue, heatingLoad: row.heatingLoad,
            coolingLoad: .init(total: row.coolingTotal, sensible: row.coolingSensible),
            registerCount: 1, projectID: projectID)
          byName[name] = model
        }
        imported.append(model)
      }

      if updateDistribution {
        // Resolve names against both the imported rooms and rooms already in the project.
        for (row, model) in zip(rows, imported) {
          if let targetName = row.delegatedToName, !key(targetName).isEmpty {
            guard let target = byName[key(targetName)] else {
              throw RoomImportError(
                "Could not find the room '\(targetName)' for airflow delegation. No rooms were changed."
              )
            }
            model.$room.id = try target.requireID()
            model.registerCount = 0
          } else {
            model.$room.id = nil
            model.registerCount = row.registerCount == 0 ? 1 : row.registerCount
          }
        }
        // Check the final graph, including existing rooms outside the import. Updating a
        // room must not turn someone else's delegation target into another delegated room.
        let byID = Dictionary(
          uniqueKeysWithValues: try byName.values.map { (try $0.requireID(), $0) })
        for model in byName.values {
          if let targetID = model.$room.id {
            guard let target = byID[targetID], target.$room.id == nil else {
              throw RoomImportError(
                "Airflow cannot be delegated to a room that delegates elsewhere. No rooms were changed."
              )
            }
          }
        }
      }

      // A PDF supplies SHR; CSV retains the existing workflow of setting it in the project.
      if !updateDistribution && project.sensibleHeatRatio == nil {
        guard let shr = reportSHR, shr.isFinite, shr > 0, shr <= 1 else {
          throw RoomImportError(
            "The report has no valid SHR. Set the project's sensible heat ratio and import again.")
        }
        project.sensibleHeatRatio = shr
        try project.validate()
        try await project.save(on: transaction)
      }

      // Save delegation targets first, including newly imported targets.
      for model in imported.filter({ $0.$room.id == nil }) + imported.filter({ $0.$room.id != nil })
      {
        try await model.validateAndSave(on: transaction)
      }
      return try imported.map { try $0.toDTO() }
    }
  }
}
