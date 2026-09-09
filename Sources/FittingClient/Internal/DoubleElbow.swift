import ManualDCore

extension Catalog {
  func evaluateDoubleElbow(
    _ record: Record, request: Fitting.EvaluationRequest,
    baseID: Fitting.ID?, inputs: Fitting.Inputs?
  ) -> Fitting.Evaluation {
    var issues: [Fitting.Issue] = []
    if baseID == nil { issues.append(.init(.missingInput, field: .baseFitting)) }
    if inputs == nil { issues.append(.init(.missingInput, field: .baseInputs)) }
    guard let baseID, let inputs else { return .unresolved(issues) }
    guard record.rule.baseFittingIDs?.contains(baseID) == true,
      let base = byID[baseID], base.shape == record.shape, isSingleElbow(base)
    else {
      return .unresolved([.init(.unsupportedCombination, field: .baseFitting)])
    }
    // Check the rule before dispatch: even malformed catalog links cannot recurse into an arrangement.
    switch inputs {
    case .roundElbow(_, let angle), .rectangularElbow(_, _, let angle):
      if let angle, angle != .degrees90 {
        return .unresolved([.init(.unsupportedCombination, field: .elbowAngle)])
      }
    case .fixed, .squareElbow: break
    default: return .unresolved([.init(.incompatibleInputs, field: .baseInputs)])
    }
    let result = evaluate(.init(pathType: request.pathType, fittingID: baseID, inputs: inputs))
    guard case .resolved(let calculation) = result else { return result }
    guard let multiplier = record.rule.multiplier, multiplier.isFinite, multiplier > 0 else {
      return .unresolved([.init(.unsupportedCombination)])
    }
    let feet = calculation.equivalentLengthFeet * multiplier
    guard feet.isFinite else { return .unresolved([.init(.unsupportedCombination)]) }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode, equivalentLengthFeet: feet,
        inputs: request.inputs,
        components: [.init(ruleKey: record.id.rawValue + ":pair", equivalentLengthFeet: feet)],
        conditions: record.conditions, catalogRevision: revision, ruleRevision: record.ruleRevision,
        derivation: .scaled(base: calculation, multiplier: multiplier)))
  }

  func isSingleElbow(_ record: Record) -> Bool {
    guard record.groupID == .elbows else { return false }
    switch record.rule.kind {
    case .roundElbow, .rectangularElbow, .squareElbow: return true
    case .fixed: return record.id == "8A-mitered"
    default: return false
    }
  }
}
