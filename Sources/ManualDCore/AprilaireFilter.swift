import Foundation

/// A media filter from Aprilaire's air cleaner pressure drop chart.
///
/// Used on the friction rate page to look up a filter's pressure loss at the project's airflow.
public struct AprilaireFilter: Equatable, Identifiable, Sendable {

  /// Filter number printed on the filter, e.g. `413`.
  public let model: String
  public let rating: Rating
  /// Chart pressure drops (in. w.c.) at 200 CFM steps, starting at `firstCFM`.
  let pressureDrops: [Double]
  let firstCFM: Int

  public var id: String { model }

  /// The chart's last column, which Aprilaire lists as the maximum recommended airflow.
  public var maxCFM: Int { firstCFM + (pressureDrops.count - 1) * Self.step }

  public var componentName: String { "Aprilaire \(model) filter" }

  static let step = 200

  /// Pressure drop at `cfm`, rounded up to 0.01 in. w.c. so it never understates the chart.
  ///
  /// Airflow between chart columns is interpolated, below the first column it scales from zero,
  /// and above `maxCFM` it follows the last chart segment.
  public func pressureDrop(at cfm: Int) -> Double {
    let chart = pressureDrops.enumerated().map {
      (cfm: firstCFM + $0.offset * Self.step, drop: $0.element)
    }
    let points = [(cfm: 0, drop: 0.0)] + chart
    let upper = points.firstIndex { $0.cfm >= cfm }.map { max($0, 1) } ?? points.count - 1
    let (low, high) = (points[upper - 1], points[upper])
    let drop =
      low.drop + (high.drop - low.drop) * Double(cfm - low.cfm) / Double(high.cfm - low.cfm)
    return max(0.01, (drop * 100 - 1e-9).rounded(.up) / 100)
  }
}

extension AprilaireFilter {
  public enum Rating: CaseIterable, Sendable {
    case merv16, merv13, merv13OdorReduction, merv11, merv10, electronicAirCleaner

    public var title: String {
      switch self {
      case .merv16: "MERV 16 · Allergy & Asthma"
      case .merv13: "MERV 13 · Healthy Home"
      case .merv13OdorReduction: "MERV 13 · Odor Reduction"
      case .merv11: "MERV 11 · Clean Air"
      case .merv10: "MERV 10"
      case .electronicAirCleaner: "Electronic air cleaner"
      }
    }
  }

  public static func named(_ model: String) -> Self? {
    all.first { $0.model.caseInsensitiveCompare(model) == .orderedSame }
  }

  /// Values from Aprilaire's "Air Cleaner Filters" pressure drop chart, in chart order.
  public static let all: [Self] = [
    .init("216", .merv16, from: 400, [0.06, 0.09, 0.13, 0.17, 0.23, 0.29, 0.36]),
    .init("416", .merv16, from: 400, [0.07, 0.10, 0.13, 0.18, 0.24, 0.31]),
    .init(
      "516", .merv16, from: 400,
      [0.04, 0.05, 0.07, 0.09, 0.10, 0.13, 0.15, 0.18, 0.21, 0.24, 0.27, 0.31]),
    .init("113", .merv13, from: 200, [0.03, 0.07, 0.11, 0.16, 0.22, 0.29]),
    .init("213", .merv13, from: 200, [0.02, 0.04, 0.06, 0.09, 0.12, 0.15, 0.19, 0.23, 0.27, 0.31]),
    .init("313", .merv13, from: 200, [0.03, 0.05, 0.09, 0.13, 0.17, 0.23]),
    .init("413", .merv13, from: 200, [0.02, 0.05, 0.07, 0.10, 0.14, 0.17, 0.22, 0.26, 0.31, 0.37]),
    .init(
      "513", .merv13, from: 200,
      [0.01, 0.02, 0.04, 0.05, 0.05, 0.07, 0.08, 0.10, 0.11, 0.13, 0.15, 0.17, 0.18, 0.20, 0.23]),
    .init("613", .merv13, from: 200, [0.02, 0.05, 0.07, 0.10, 0.14, 0.17, 0.22, 0.26, 0.31, 0.37]),
    .init("813", .merv13, from: 200, [0.02, 0.04, 0.06, 0.09, 0.12, 0.15, 0.19, 0.23, 0.27, 0.31]),
    .init("913", .merv13, from: 400, [0.04, 0.07, 0.10, 0.13, 0.17, 0.22, 0.25, 0.30, 0.35]),
    .init(
      "213CBN", .merv13OdorReduction, from: 400,
      [0.04, 0.07, 0.10, 0.13, 0.17, 0.21, 0.25, 0.30, 0.35]),
    .init(
      "413CBN", .merv13OdorReduction, from: 400,
      [0.04, 0.07, 0.10, 0.14, 0.19, 0.24, 0.29, 0.36, 0.43]),
    .init(
      "513CBN", .merv13OdorReduction, from: 400,
      [0.03, 0.04, 0.05, 0.07, 0.08, 0.10, 0.12, 0.15, 0.17, 0.20, 0.22, 0.25, 0.29, 0.32]),
    .init("110", .merv11, from: 200, [0.02, 0.05, 0.06, 0.10, 0.14, 0.20]),
    .init("210", .merv11, from: 200, [0.02, 0.03, 0.04, 0.06, 0.08, 0.11, 0.13, 0.16, 0.19, 0.22]),
    .init("310", .merv11, from: 200, [0.02, 0.04, 0.06, 0.10, 0.14, 0.19]),
    .init("410", .merv11, from: 200, [0.02, 0.03, 0.05, 0.07, 0.09, 0.12, 0.15, 0.19, 0.22, 0.27]),
    .init(
      "510", .merv11, from: 200,
      [0.02, 0.02, 0.03, 0.04, 0.04, 0.05, 0.06, 0.07, 0.09, 0.10, 0.12, 0.14, 0.15, 0.17, 0.19]),
    .init("610", .merv11, from: 200, [0.02, 0.03, 0.05, 0.07, 0.09, 0.12, 0.15, 0.19, 0.22, 0.27]),
    .init("810", .merv11, from: 200, [0.02, 0.03, 0.04, 0.06, 0.08, 0.11, 0.13, 0.16, 0.19, 0.22]),
    .init("910", .merv11, from: 400, [0.03, 0.05, 0.07, 0.09, 0.12, 0.15, 0.18, 0.22, 0.27]),
    .init("201", .merv10, from: 200, [0.02, 0.04, 0.05, 0.08, 0.10, 0.12, 0.15, 0.18, 0.21, 0.25]),
    .init("401", .merv10, from: 200, [0.02, 0.04, 0.05, 0.08, 0.10, 0.14, 0.17, 0.21, 0.25, 0.29]),
    .init(
      "501", .electronicAirCleaner, from: 200,
      [0.02, 0.04, 0.05, 0.08, 0.10, 0.14, 0.17, 0.21, 0.25, 0.29]),
  ]

  private init(_ model: String, _ rating: Rating, from firstCFM: Int, _ pressureDrops: [Double]) {
    self.model = model
    self.rating = rating
    self.firstCFM = firstCFM
    self.pressureDrops = pressureDrops
  }
}
