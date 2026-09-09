import ManualDCore

extension Catalog {
  func evaluateTransition(_ record: Record, request: Fitting.EvaluationRequest)
    -> Fitting.Evaluation
  {
    let row: Rule.Row?
    var issues: [Fitting.Issue] = []
    var referenceVelocity = record.conditions.referenceVelocityFPM
    switch request.inputs {
    case .transition(let slope, let ratio):
      if slope == nil { issues.append(.init(.missingInput, field: .transitionSlope)) }
      if ratio == nil { issues.append(.init(.missingInput, field: .areaRatio)) }
      guard let slope, let ratio else { return .unresolved(issues) }
      row = record.rule.rows.first { $0.slope == slope && $0.parameter == Double(ratio.rawValue) }
    case .plenumPassage(let inlet, let outlet):
      if inlet == nil { issues.append(.init(.missingInput, field: .inletVelocity)) }
      if outlet == nil { issues.append(.init(.missingInput, field: .outletVelocity)) }
      guard let inlet, let outlet else { return .unresolved(issues) }
      row = record.rule.rows.first { $0.inletVelocity == inlet && $0.outletVelocity == outlet }
    case .abruptSqueeze(let velocity, let ratio):
      if velocity == nil { issues.append(.init(.missingInput, field: .upstreamVelocity)) }
      if ratio == nil { issues.append(.init(.missingInput, field: .areaRatio)) }
      guard let velocity, let ratio else { return .unresolved(issues) }
      row = record.rule.rows.first {
        $0.inletVelocity == velocity && $0.parameter == Double(ratio.rawValue)
      }
      referenceVelocity = velocity.rawValue
    default: return .unresolved([.init(.incompatibleInputs)])
    }
    guard let row else { return .unresolved([.init(.unsupportedCombination)]) }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode,
        equivalentLengthFeet: row.feet, inputs: request.inputs,
        components: [.init(ruleKey: row.key, equivalentLengthFeet: row.feet)],
        conditions: .init(
          referenceVelocityFPM: referenceVelocity,
          frictionRateIWCPer100Feet: record.conditions.frictionRateIWCPer100Feet,
          notes: record.conditions.notes),
        catalogRevision: revision, ruleRevision: record.ruleRevision,
        minimumUpstreamStaticPressureIWC: row.minimumUpstreamStaticPressureIWC))
  }
}
