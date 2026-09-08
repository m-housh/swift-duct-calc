import DatabaseClient
import Dependencies
import FittingClient
import Foundation
import ManualDCore

extension ProjectClient {
  public func createPathTemplate(userID: User.ID, configuration: PathTemplate.Configuration)
    async throws -> PathTemplate
  {
    @Dependency(\.templateFittingClient) var fittings
    @Dependency(\.database.pathTemplates) var templates
    try await fittings.validateTemplate(configuration)
    return try await templates.create(userID, configuration)
  }

  public func updatePathTemplate(
    userID: User.ID, id: PathTemplate.ID, revision: UUID, configuration: PathTemplate.Configuration
  ) async throws -> PathTemplate {
    @Dependency(\.templateFittingClient) var fittings
    @Dependency(\.database.pathTemplates) var templates
    try await fittings.validateTemplate(configuration)
    return try await templates.update(userID, id, revision, configuration)
  }

  public func saveGuidedPath(
    userID: User.ID, projectID: Project.ID, request: GuidedPath.SaveRequest
  )
    async throws -> EquivalentLength
  {
    @Dependency(\.database) var database
    @Dependency(\.templateFittingClient) var fittings
    guard try await database.projects.getForUser(projectID, userID) != nil else {
      throw NotFoundError()
    }
    let existing: EquivalentLength?
    let snapshot: PathTemplate.Snapshot
    if let id = request.id {
      guard let saved = try await database.equivalentLengths.get(id), saved.projectID == projectID,
        let savedSnapshot = saved.templateSnapshot
      else { throw NotFoundError() }
      existing = saved
      snapshot = savedSnapshot
    } else {
      guard try await database.pathTemplates.get(userID, request.snapshot.templateID) != nil else {
        throw NotFoundError()
      }
      existing = nil
      snapshot = request.snapshot
    }
    try await fittings.validateTemplate(snapshot.configuration)
    guard !request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      request.name.count <= 200, request.rows.count <= 1000,
      Set(request.rows.map(\.id)).count == request.rows.count,
      request.straightLengths.count <= 100,
      request.straightLengths.allSatisfy({ $0 > 0 })
    else { throw ValidationError("Check the path name, lengths, and fitting rows.") }
    let configuration = snapshot.configuration
    for step in configuration.steps {
      let rows = request.rows.filter { $0.stepID == step.id }
      guard step.allowsSkipping || !rows.isEmpty else {
        throw ValidationError("Complete \(step.title) before saving.")
      }
      guard step.behavior != .chooseOne || rows.count <= 1 else {
        throw ValidationError("Choose one fitting for \(step.title).")
      }
      if step.behavior == .quantities,
        Set(rows.map(\.fittingID)).count != rows.count
      {
        throw ValidationError("Combine repeated quantities in \(step.title).")
      }
    }
    let definitions = try await fittings.fittings(configuration.type)
    let stepOrder = Dictionary(
      uniqueKeysWithValues: configuration.steps.enumerated().map {
        ($0.element.id, $0.offset)
      })
    let orderedRows = request.rows.enumerated().sorted { lhs, rhs in
      let left = lhs.element.stepID.flatMap { stepOrder[$0] } ?? stepOrder.count
      let right = rhs.element.stepID.flatMap { stepOrder[$0] } ?? stepOrder.count
      return left == right ? lhs.offset < rhs.offset : left < right
    }.map(\.element)
    var groups = [EquivalentLength.FittingGroup]()
    for row in orderedRows {
      guard row.quantity > 0, row.quantity <= 10000,
        let definition = definitions.first(where: { $0.id == row.fittingID }),
        let code = definition.sourceCode
      else { throw ValidationError("Check the fitting and its quantity.") }
      if let stepID = row.stepID {
        guard let step = configuration.steps.first(where: { $0.id == stepID }),
          step.choices.contains(where: { $0.fittingID == row.fittingID })
        else { throw ValidationError("This fitting is not a choice in its section.") }
      }
      let calculation: TemplateFitting.Calculation
      if let stored = existing?.groups.first(where: { $0.rowID == row.id })?.calculation,
        stored.fittingID == row.fittingID, stored.inputs == row.inputs
      {
        calculation = stored
      } else {
        switch try await fittings.evaluate(
          .init(type: configuration.type, fittingID: row.fittingID, inputs: row.inputs)
        ) {
        case .resolved(let result): calculation = result
        case .unresolved(let message): throw ValidationError(message)
        }
      }
      groups.append(
        .init(
          group: definition.group.rawValue, letter: String(code.drop { $0.isNumber }),
          value: calculation.equivalentLengthFeet, quantity: row.quantity,
          fitting: calculation.catalogCalculation.map {
            .init(id: row.id, origin: .catalog, name: definition.name, calculation: $0)
          },
          rowID: row.id, stepID: row.stepID, calculation: calculation
        ))
    }
    guard groups.totalEquivalentLength.isFinite else {
      throw ValidationError("The fitting total is too large.")
    }
    if let existing {
      return try await database.equivalentLengths.update(
        existing.id,
        .init(
          name: request.name, type: configuration.type, straightLengths: request.straightLengths,
          groups: groups, templateSnapshot: snapshot
        ))
    }
    return try await database.equivalentLengths.create(
      .init(
        projectID: projectID, name: request.name, type: configuration.type,
        straightLengths: request.straightLengths, groups: groups, templateSnapshot: snapshot
      ))
  }
}
