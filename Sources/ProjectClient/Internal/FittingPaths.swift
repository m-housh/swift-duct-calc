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
  let name: String
  do {
    name = try PathValidation.name(
      request.name, straightLengths: request.straightLengths, rowCount: request.entries.count)
  } catch let error as ValidationError { throw FittingPathError(error.message) }
  var saved: EquivalentLength?
  if let baseline = request.baseline {
    guard baseline.projectID == projectID,
      let current = try await database.equivalentLengths.get(baseline.id),
      current.projectID == projectID
    else { throw FittingPathError("Path not found.") }
    guard current.templateSnapshot == nil else {
      throw FittingPathError(
        "Open this path in the guided editor to keep its sections and fitting details.")
    }
    guard current == baseline else {
      throw FittingPathError(
        "This path changed since you opened it. Reload it before saving; your draft has been kept.")
    }
    saved = current
  }
  let allowed = Set(try await client.groups(request.pathType).map(\.id.rawValue))
  var groups: [EquivalentLength.FittingGroup] = []
  var usedSaved = Set<Int>()
  func rowID(replacing index: Int?) throws -> UUID {
    guard let index else { return uuid() }
    guard let saved, saved.groups.indices.contains(index), usedSaved.insert(index).inserted else {
      throw FittingPathError("The edited row does not identify an existing fitting.")
    }
    return saved.groups[index].fitting?.id ?? uuid()
  }
  for (index, entry) in request.entries.enumerated() {
    let group: EquivalentLength.FittingGroup
    switch entry {
    case .saved(let i, let q):
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
    case .reference(let code, let feet, let q, let replacing):
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
        fitting: .init(
          id: try rowID(replacing: replacing), origin: .referenceEntry, name: "Reference entry"))
    case .catalog(let id, let inputs, let column, let q, let replacing):
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
      var metadata = Fitting.SavedEntry(
        id: try rowID(replacing: replacing), origin: .catalog, name: definition.name)
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
    groups.append(group)
  }
  do { try PathValidation.validate(groups) } catch let error as ValidationError {
    throw FittingPathError(error.message)
  }
  if let saved {
    return try await database.equivalentLengths.updateIfUnchanged(
      saved,
      .init(
        name: name, type: request.pathType, straightLengths: request.straightLengths, groups: groups
      ))
  }
  return try await database.equivalentLengths.create(
    .init(
      projectID: projectID, name: name, type: request.pathType,
      straightLengths: request.straightLengths, groups: groups))
}
