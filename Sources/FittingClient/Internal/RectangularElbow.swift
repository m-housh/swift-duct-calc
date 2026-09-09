import ManualDCore

extension Catalog {
  func evaluateRectangularElbow(
    _ record: Record, request: Fitting.EvaluationRequest,
    radiusRatio: Fitting.RectangularElbowRadiusRatio?, bendCategory: Fitting.ElbowBendCategory?,
    angle: Fitting.ElbowAngle?
  ) -> Fitting.Evaluation {
    var issues: [Fitting.Issue] = []
    if radiusRatio == nil { issues.append(.init(.missingInput, field: .radiusRatio)) }
    if bendCategory == nil { issues.append(.init(.missingInput, field: .bendCategory)) }
    if angle == nil { issues.append(.init(.missingInput, field: .elbowAngle)) }
    guard let radiusRatio, let bendCategory, let angle else { return .unresolved(issues) }
    guard
      let row = record.rule.rows.first(where: {
        $0.parameter == radiusRatio.rawValue && $0.bendCategory == bendCategory
      })
    else {
      return .unresolved([.init(.unsupportedCombination)])
    }
    guard let factor = record.rule.angleMultipliers?.first(where: { $0.angle == angle }) else {
      return .unresolved([.init(.unsupportedCombination, field: .elbowAngle)])
    }
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
