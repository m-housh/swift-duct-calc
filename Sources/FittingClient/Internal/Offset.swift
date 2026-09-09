import ManualDCore

extension Catalog {
  func evaluateOffset(_ record: Record, request: Fitting.EvaluationRequest) -> Fitting.Evaluation {
    let row: Rule.Row?
    var turningVanes = false
    switch request.inputs {
    case .squareElbow(let category):
      guard let category else { return .unresolved([.init(.missingInput, field: .bendCategory)]) }
      row = record.rule.rows.first { $0.bendCategory == category }
    case .steppedOffset(let ratio):
      guard let ratio else { return .unresolved([.init(.missingInput, field: .offsetRatio)]) }
      row = record.rule.rows.first { $0.parameter == ratio.rawValue }
    case .fourTurnOffset(let ratio, let vanes):
      guard let ratio else { return .unresolved([.init(.missingInput, field: .offsetRatio)]) }
      row = record.rule.rows.first { $0.parameter == ratio.rawValue }
      turningVanes = vanes
    case .radiusOffset(let ratio):
      guard let ratio else { return .unresolved([.init(.missingInput, field: .offsetRatio)]) }
      row = record.rule.rows.first { $0.parameter == ratio.rawValue }
    case .riserElbow(let size, let corner):
      var issues: [Fitting.Issue] = []
      if size == nil { issues.append(.init(.missingInput, field: .riserSize)) }
      if corner == nil { issues.append(.init(.missingInput, field: .riserCorner)) }
      guard let size, let corner else { return .unresolved(issues) }
      row = record.rule.rows.first { $0.riserSize == size && $0.riserCorner == corner }
    default:
      return .unresolved([.init(.incompatibleInputs)])
    }
    guard let row else { return .unresolved([.init(.unsupportedCombination)]) }
    let feet: Double
    let key: String
    if record.rule.kind == .fourTurnOffset {
      // The dash at H/L = 0.5 with vanes is unavailable, never zero or the unvaned value.
      guard let value = turningVanes ? row.vanedFeet : row.feet else {
        return .unresolved([.init(.unsupportedCombination, field: .turningVanes)])
      }
      feet = value
      key = row.key + (turningVanes ? ":with-vanes" : ":without-vanes")
    } else {
      feet = row.feet
      key = row.key
    }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode, equivalentLengthFeet: feet,
        inputs: request.inputs, components: [.init(ruleKey: key, equivalentLengthFeet: feet)],
        conditions: record.conditions, catalogRevision: revision, ruleRevision: record.ruleRevision)
    )
  }
}
