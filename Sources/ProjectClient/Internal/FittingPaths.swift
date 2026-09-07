import DatabaseClient
import Dependencies
import FittingClient
import Foundation
import ManualDCore

public struct FittingPathError: Error, CustomStringConvertible {
  public let description: String
  init(_ description: String) { self.description = description }
}

func persistFittingPath(userID: User.ID, projectID: Project.ID, request: Fitting.PathSave)
  async throws -> EquivalentLength
{
  @Dependency(\.database) var database
  @Dependency(\.fittingClient) var client
  @Dependency(\.uuid) var uuid
  guard try await database.projects.getForUser(projectID, userID) != nil else {
    throw FittingPathError("Project not found.")
  }
  let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !name.isEmpty, name.count <= 200, request.entries.count <= 500,
    request.straightLengths.count <= 100, request.straightLengths.allSatisfy({ $0 > 0 })
  else {
    throw FittingPathError(
      "Enter a path name and positive straight lengths (up to 100 lengths and 500 fittings).")
  }
  var saved: EquivalentLength?
  if let baseline = request.baseline {
    guard baseline.projectID == projectID,
      let current = try await database.equivalentLengths.get(baseline.id),
      current.projectID == projectID
    else { throw FittingPathError("Path not found.") }
    guard current == baseline else {
      throw FittingPathError(
        "This path changed since you opened it. Reload it before saving; your draft has been kept.")
    }
    saved = current
  }
  let allowed = Set(try await client.groups(request.pathType).map(\.id.rawValue))
  var groups: [EquivalentLength.FittingGroup] = []
  var usedSaved = Set<Int>()
  for (index, entry) in request.entries.enumerated() {
    let quantity: Int
    let group: EquivalentLength.FittingGroup
    switch entry {
    case .saved(let i, let q):
      quantity = q
      guard let saved, saved.groups.indices.contains(i), usedSaved.insert(i).inserted else {
        throw FittingPathError("Row \(index + 1) does not identify an existing fitting.")
      }
      let old = saved.groups[i]
      guard allowed.contains(old.group) else {
        throw FittingPathError(
          "Row \(index + 1) belongs to the other path type. Keep the original type or remove that row explicitly."
        )
      }
      group = .init(
        group: old.group, letter: old.letter, value: old.value, quantity: q,
        fitting: old.fitting ?? .init(id: uuid(), origin: .legacy, name: "Saved reference entry"))
    case .reference(let code, let feet, let q):
      quantity = q
      guard feet.isFinite, feet > 0,
        case .recognized(let reference) = try await client.resolveReference(
          .init(code: code, pathType: request.pathType))
      else {
        throw FittingPathError(
          "Row \(index + 1): enter a recognized code for this path and a positive equivalent length."
        )
      }
      group = .init(
        group: reference.groupID.rawValue,
        letter: String(reference.code.rawValue.drop(while: { $0.isNumber })), value: feet,
        quantity: q,
        fitting: .init(id: uuid(), origin: .referenceEntry, name: "Reference entry"))
    case .catalog(let id, let inputs, let column, let q):
      quantity = q
      let result = try await client.evaluate(
        .init(pathType: request.pathType, fittingID: id, inputs: inputs))
      var definition: Fitting.Definition?
      for groupID in allowed.sorted() {
        definition = try await client.fittings(
          .init(pathType: request.pathType, groupID: .init(rawValue: groupID)!)
        ).first { $0.id == id }
        if definition != nil { break }
      }
      guard let definition else { throw FittingPathError("Row \(index + 1): fitting unavailable.") }
      var metadata = Fitting.SavedEntry(id: uuid(), origin: .catalog, name: definition.name)
      let feet: Double
      switch result {
      case .resolved(let value):
        feet = value.equivalentLengthFeet
        metadata.calculation = value
      case .resolvedReturnJunction(let value):
        guard let column, let component = column == .branch ? value.branch : value.trunk else {
          throw FittingPathError(
            "Row \(index + 1): choose an available branch or trunk contribution.")
        }
        feet = component.equivalentLengthFeet
        metadata.returnJunction = value
        metadata.column = column
      case .unresolved:
        throw FittingPathError("Row \(index + 1): complete the fitting inputs before saving.")
      }
      group = .init(
        group: definition.groupID.rawValue,
        letter: String((definition.sourceCode?.rawValue ?? "").drop(while: { $0.isNumber })),
        value: feet, quantity: q, fitting: metadata)
    }
    guard quantity > 0, quantity <= 1_000_000, group.value.isFinite,
      (group.value * Double(quantity)).isFinite
    else { throw FittingPathError("Row \(index + 1): quantity must be between 1 and 1,000,000.") }
    groups.append(group)
  }
  guard
    (groups.totalEquivalentLength + request.straightLengths.reduce(0.0, { $0 + Double($1) }))
      .isFinite
  else { throw FittingPathError("The path total is too large.") }
  if let saved {
    return try await database.equivalentLengths.update(
      saved.id,
      .init(
        name: name, type: request.pathType, straightLengths: request.straightLengths, groups: groups
      ))
  }
  return try await database.equivalentLengths.create(
    .init(
      projectID: projectID, name: name, type: request.pathType,
      straightLengths: request.straightLengths, groups: groups))
}
