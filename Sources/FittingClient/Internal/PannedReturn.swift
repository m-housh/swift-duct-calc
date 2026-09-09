import ManualDCore

extension Catalog {
  func evaluatePannedReturn(
    _ record: Record, request: Fitting.EvaluationRequest, airflowCFM: Double?, mergingFlow: Bool
  ) -> Fitting.Evaluation {
    guard let airflowCFM else {
      return .unresolved([.init(.missingInput, field: .airflowCFM)])
    }
    guard airflowCFM.isFinite else {
      return .unresolved([.init(.nonfiniteInput, field: .airflowCFM)])
    }
    guard airflowCFM > 0 else {
      return .unresolved([.init(.nonpositiveAirflow, field: .airflowCFM)])
    }
    let rows = record.rule.rows
    // Enforce source limits before rounding; a nearby row cannot extend the supported range.
    guard airflowCFM >= rows[0].parameter, airflowCFM <= rows[rows.count - 1].parameter else {
      return .unresolved([.init(.unsupportedAirflow, field: .airflowCFM)])
    }
    guard !mergingFlow || record.rule.mergingFlowFeet != nil else {
      return .unresolved([.init(.unsupportedCombination, field: .mergingFlow)])
    }
    // Group 7 uses whole-CFM rows and exactly representable midpoints. Ties select the upper row.
    let row =
      zip(rows, rows.dropFirst()).first { lower, upper in
        airflowCFM < (lower.parameter + upper.parameter) / 2
      }?.0 ?? rows[rows.count - 1]
    var components: [Fitting.Calculation.Component] = [
      .init(ruleKey: row.key, equivalentLengthFeet: row.feet)
    ]
    if mergingFlow, let feet = record.rule.mergingFlowFeet {
      components.append(
        .init(ruleKey: "\(record.id.rawValue):merging-flow", equivalentLengthFeet: feet))
    }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode,
        equivalentLengthFeet: components.reduce(0) { $0 + $1.equivalentLengthFeet },
        inputs: request.inputs, components: components, conditions: record.conditions,
        catalogRevision: revision, ruleRevision: record.ruleRevision,
        airflowSelection: .init(submittedCFM: airflowCFM, selectedCFM: row.parameter)
      ))
  }
}
