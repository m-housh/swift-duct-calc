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
    case (.doubleElbow, .doubleElbow(let baseID, let inputs)):
      return evaluateDoubleElbow(record, request: request, baseID: baseID, inputs: inputs)
    case (.insideCornerOffset, .insideCornerOffset(let radius)):
      guard let radius else {
        return .unresolved([.init(.missingInput, field: .insideCornerRadius)])
      }
      guard let match = record.rule.rows.first(where: { $0.insideCornerRadius == radius }) else {
        return .unresolved([.init(.unsupportedCombination, field: .insideCornerRadius)])
      }
      row = match
    case (.squareElbow, .squareElbow), (.steppedOffset, .steppedOffset),
      (.fourTurnOffset, .fourTurnOffset), (.radiusOffset, .radiusOffset),
      (.riserElbow, .riserElbow):
      return evaluateOffset(record, request: request)
    case (.fixed, .fixed):
      row = record.rule.rows[0]
    case (.ovalElbow, .ovalElbow(let pieceCount)):
      guard let pieceCount else {
        return .unresolved([.init(.missingInput, field: .pieceCount)])
      }
      guard
        let match = record.rule.rows.first(where: { $0.parameter == Double(pieceCount.rawValue) })
      else {
        return .unresolved([.init(.unsupportedCombination, field: .pieceCount)])
      }
      row = match
    case (.heightWidth, .heightWidth(let numerator, let width)),
      (.radiusWidth, .radiusWidth(let numerator, let width)):
      let numeratorField: Fitting.Issue.Field =
        record.rule.kind == .heightWidth ? .heightInches : .radiusInches
      var issues: [Fitting.Issue] = []
      for (number, field) in [(numerator, numeratorField), (width, .widthInches)] {
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
      guard issues.isEmpty, let numerator, let width else { return .unresolved(issues) }
      let ratio = numerator / width
      // Use only printed H/W or R/W rows. No interpolation or near-row tolerance.
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
      // The final source bucket is inclusive (5+ in group 2). Preserve the submitted count.
      row = record.rule.rows[min(count, record.rule.rows.count - 1)]
    case (.plenumReturns, .plenumReturns(let count)):
      guard let count else {
        return .unresolved([.init(.missingInput, field: .plenumReturns)])
      }
      guard count > 0 else {
        return .unresolved([.init(.nonpositiveReturnCount, field: .plenumReturns)])
      }
      // Group 5 starts at one return; the final bucket covers two or more.
      row = record.rule.rows[min(count, record.rule.rows.count) - 1]
    case (.junction, .junction(let path)):
      guard let path else {
        return .unresolved([.init(.missingInput, field: .junctionPath)])
      }
      guard let match = record.rule.rows.first(where: { $0.path == path }) else {
        return .unresolved([.init(.unsupportedCombination, field: .junctionPath)])
      }
      row = match
    case (.rectangularElbow, .rectangularElbow(let radiusRatio, let bendCategory, let angle)):
      return evaluateRectangularElbow(
        record, request: request, radiusRatio: radiusRatio, bendCategory: bendCategory, angle: angle
      )
    case (.roundElbow, .roundElbow(let radiusRatio, let angle)):
      return evaluateRoundElbow(record, request: request, radiusRatio: radiusRatio, angle: angle)
    case (.pannedReturn, .pannedReturn(let airflowCFM, let mergingFlow)):
      return evaluatePannedReturn(
        record, request: request, airflowCFM: airflowCFM, mergingFlow: mergingFlow)
    case (.returnJunction, .returnJunction(let branchCFM, let totalCFM)):
      return evaluateReturnJunction(
        record, request: request, branchCFM: branchCFM, totalCFM: totalCFM)
    default:
      return .unresolved([.init(.incompatibleInputs)])
    }
    return .resolved(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode, equivalentLengthFeet: row.feet,
        inputs: request.inputs,
        components: [.init(ruleKey: row.key, equivalentLengthFeet: row.feet)],
        conditions: record.conditions, catalogRevision: revision, ruleRevision: record.ruleRevision
      ))
  }
}
