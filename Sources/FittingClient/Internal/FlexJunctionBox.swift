import ManualDCore

extension Catalog {
  func evaluateFlexJunctionBox(_ record: Record, request: Fitting.EvaluationRequest)
    -> Fitting.Evaluation
  {
    guard
      case .flexJunctionBox(
        let velocity, let openings, let suppliedBend, let bendVelocity, let radius) = request.inputs
    else { return .unresolved([.init(.incompatibleInputs)]) }
    var issues: [Fitting.Issue] = []
    if velocity == nil { issues.append(.init(.missingInput, field: .flexVelocity)) }
    if openings == nil { issues.append(.init(.missingInput, field: .flexOpenings)) }
    if suppliedBend {
      if bendVelocity == nil { issues.append(.init(.missingInput, field: .bendVelocity)) }
      if radius == nil { issues.append(.init(.missingInput, field: .bendRadiusRatio)) }
    }
    guard issues.isEmpty, let velocity, let openings else { return .unresolved(issues) }
    guard openings == .sidewall else {
      return .unresolved([.init(.unsupportedCombination, field: .flexOpenings)])
    }
    guard let row = record.rule.rows.first(where: { $0.parameter == Double(velocity.rawValue) })
    else {
      return .unresolved([.init(.unsupportedCombination, field: .flexVelocity)])
    }
    var components = [
      Fitting.Calculation.Component(ruleKey: row.key, equivalentLengthFeet: row.feet)
    ]
    if suppliedBend, let bendVelocity, let radius {
      guard
        let bend = record.rule.rows.first(where: { $0.parameter == Double(bendVelocity.rawValue) })?
          .flexBends?.first(where: { $0.radiusRatio == radius })
      else {
        return .unresolved([.init(.unsupportedCombination, field: .bendRadiusRatio)])
      }
      components.append(
        .init(
          ruleKey: "11-radius-bend:\(bendVelocity.rawValue):\(radius.rawValue)",
          equivalentLengthFeet: bend.feet))
    }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: nil,
        equivalentLengthFeet: components.reduce(0) { $0 + $1.equivalentLengthFeet },
        inputs: request.inputs, components: components, conditions: record.conditions,
        catalogRevision: revision, ruleRevision: record.ruleRevision))
  }
}
