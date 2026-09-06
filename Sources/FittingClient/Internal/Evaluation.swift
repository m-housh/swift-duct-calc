import Foundation
import ManualDCore

extension Catalog {
  func evaluate(_ request: Fitting.EvaluationRequest) -> Fitting.Evaluation {
    guard let record = byID[request.fittingID] else { return .unresolved([.init(.unknownFitting)]) }
    guard pathTypes(for: record).contains(request.pathType) else {
      return .unresolved([.init(.ineligiblePathType)])
    }
    let row: Rule.Row
    switch (record.rule.kind, request.inputs) {
    case (.fixed, .fixed):
      row = record.rule.rows[0]
    case (.heightWidth, .heightWidth(let height, let width)):
      var issues: [Fitting.Issue] = []
      for (number, field) in [(height, Fitting.Issue.Field.heightInches), (width, .widthInches)] {
        guard let number else {
          issues.append(.init(.missingInput, field: field))
          continue
        }
        if !number.isFinite {
          issues.append(.init(.nonfiniteInput, field: field))
        } else if number <= 0 {
          issues.append(.init(.nonpositiveDimension, field: field))
        }
      }
      guard issues.isEmpty, let height, let width else { return .unresolved(issues) }
      let ratio = height / width
      // Source 1F lists exact H/W rows only. No interpolation or near-row tolerance.
      guard ratio.isFinite, let match = record.rule.rows.first(where: { $0.parameter == ratio })
      else {
        return .unresolved([.init(.unsupportedRatio)])
      }
      row = match
    case (.downstreamBranches, .downstreamBranches(let count)):
      guard let count else {
        return .unresolved([.init(.missingInput, field: .downstreamBranches)])
      }
      guard count >= 0 else {
        return .unresolved([.init(.negativeBranchCount, field: .downstreamBranches)])
      }
      // The final source bucket is inclusive (5+ for 2A). Preserve the submitted count.
      row = record.rule.rows[min(count, record.rule.rows.count - 1)]
    default:
      return .unresolved([.init(.incompatibleInputs)])
    }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode, equivalentLengthFeet: row.feet,
        inputs: request.inputs,
        components: [.init(ruleKey: row.key, equivalentLengthFeet: row.feet)],
        source: record.source, catalogRevision: revision, ruleRevision: record.ruleRevision
      ))
  }
}
