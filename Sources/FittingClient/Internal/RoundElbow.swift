import ManualDCore

extension Catalog {
  func evaluateRoundElbow(
    _ record: Record, request: Fitting.EvaluationRequest,
    radiusRatio: Fitting.RoundElbowRadiusRatio?, angle: Fitting.ElbowAngle?
  ) -> Fitting.Evaluation {
    var issues: [Fitting.Issue] = []
    if radiusRatio == nil { issues.append(.init(.missingInput, field: .radiusRatio)) }
    if angle == nil { issues.append(.init(.missingInput, field: .elbowAngle)) }
    guard let radiusRatio, let angle else { return .unresolved(issues) }
    guard let row = record.rule.rows.first(where: { $0.parameter == radiusRatio.rawValue }) else {
      return .unresolved([.init(.unsupportedRatio, field: .radiusRatio)])
    }
    guard let factor = record.rule.angleMultipliers?.first(where: { $0.angle == angle }) else {
      return .unresolved([.init(.unsupportedCombination, field: .elbowAngle)])
    }
    // The source multiplier applies to the 90° base length. Preserve fractional results.
    let feet = row.feet * factor.multiplier
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode, equivalentLengthFeet: feet,
        inputs: request.inputs,
        components: [
          .init(ruleKey: "\(row.key):angle:\(angle.rawValue)", equivalentLengthFeet: feet)
        ],
        conditions: record.conditions, catalogRevision: revision, ruleRevision: record.ruleRevision
      ))
  }
}
