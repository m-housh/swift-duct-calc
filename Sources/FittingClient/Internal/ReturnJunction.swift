import Foundation
import ManualDCore

extension Catalog {
  func evaluateReturnJunction(
    _ record: Record, request: Fitting.EvaluationRequest, branchCFM: Double?, totalCFM: Double?
  ) -> Fitting.Evaluation {
    var issues: [Fitting.Issue] = []
    for (value, field) in [(branchCFM, Fitting.Issue.Field.branchCFM), (totalCFM, .totalCFM)] {
      guard let value else {
        issues.append(.init(.missingInput, field: field))
        continue
      }
      if !value.isFinite {
        issues.append(.init(.nonfiniteInput, field: field))
      } else if value <= 0 {
        issues.append(.init(.nonpositiveAirflow, field: field))
      }
    }
    guard issues.isEmpty, let branchCFM, let totalCFM else { return .unresolved(issues) }
    guard branchCFM <= totalCFM else {
      return .unresolved([.init(.branchExceedsTotal, field: .branchCFM)])
    }
    let ratio = branchCFM / totalCFM
    let rows = record.rule.rows
    guard ratio > 0, let first = rows.first, let last = rows.last,
      ratio <= last.parameter,
      ratio >= first.parameter || record.rule.firstRowIncludesLowerRatios == true
    else {
      return .unresolved([.init(.unsupportedRatio)])
    }

    let selected: Rule.Row
    let reason: Fitting.ReturnJunctionCalculation.RatioSelection.Reason
    if let exact = rows.first(where: { $0.parameter == ratio }) {
      selected = exact
      reason = .exact
    } else if ratio < first.parameter {
      selected = first
      reason = .sourceRange
    } else {
      // The table is unevenly spaced. Select its nearest published row, with ties upward.
      // Decimal midpoints avoid treating 0.15 as below the midpoint of 0.1 and 0.2.
      selected =
        zip(rows, rows.dropFirst()).first { lower, upper in
          let midpoint = NSDecimalNumber(string: String(lower.parameter))
            .adding(NSDecimalNumber(string: String(upper.parameter)))
            .dividing(by: 2).doubleValue
          return ratio < midpoint
        }?.0 ?? last
      reason = .rounded
    }

    return .resolvedReturnJunction(
      .init(
        fittingID: record.id, sourceCode: record.sourceCode, inputs: request.inputs,
        branch: .init(ruleKey: "\(selected.key)/branch", equivalentLengthFeet: selected.feet),
        trunk: selected.trunkFeet.map {
          .init(ruleKey: "\(selected.key)/trunk", equivalentLengthFeet: $0)
        },
        ratioSelection: .init(
          calculatedRatio: ratio, selectedRatio: selected.parameter, reason: reason),
        conditions: record.conditions, catalogRevision: revision, ruleRevision: record.ruleRevision)
    )
  }
}
