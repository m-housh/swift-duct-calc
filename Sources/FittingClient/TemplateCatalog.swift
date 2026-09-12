import Foundation
import ManualDCore

extension TemplateFitting.Inputs {
  /// Restores older template inputs in the fitting editor without recalculating saved lengths.
  public func catalogInputs(for requirement: Fitting.InputRequirement) -> Fitting.Inputs? {
    TemplateCatalog.runtimeInputs(self, requirement: requirement)
  }
}

/// Adapts current catalog inputs to the saved template transport format.
/// Fitting identities, artwork, conditions, and numeric tables belong to FittingClient.
enum TemplateCatalog {
  static let runtime = Result {
    guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
      throw FittingClientError.missingCatalog
    }
    return try Catalog(data: Data(contentsOf: url))
  }

  static func requirements(_ input: Fitting.InputRequirement) -> TemplateFitting.Requirements {
    switch input {
    case .fixed: return .fixed
    case .heightWidth: return .dimensions(numerator: "H", denominator: "W")
    case .radiusWidth: return .dimensions(numerator: "R", denominator: "W")
    case .downstreamBranches: return .downstreamBranches
    case .plenumReturns(let minimum):
      return .sourceTable(axes: [
        .init(
          label: "Returns entering this plenum",
          options: (1...minimum).map { $0 == minimum ? "\($0) or more" : "\($0)" })
      ])
    case .roundElbow(let ratios, let angles):
      var axes = [
        TemplateFitting.Axis(
          label: "R/D",
          options: ratios.map {
            // Keep the option ID used by already-saved templates and exported files.
            $0.rawValue == 1.5 ? "1.5 or larger" : String(format: "%g", $0.rawValue)
          })
      ]
      if angles != [.degrees90] {
        axes.append(.init(label: "Bend angle (degrees)", options: angles.map { "\($0.rawValue)" }))
      }
      return .sourceTable(axes: axes)
    case .ovalElbow(let counts):
      return .sourceTable(axes: [
        .init(label: "Piece count", options: counts.map { "\($0.rawValue)" })
      ])
    case .transition(let slopes, let ratios):
      return .sourceTable(axes: [
        .init(label: "Slope X/Y", options: slopes.map(\.rawValue)),
        .init(label: "Larger / smaller area", options: ratios.map { "\($0.rawValue)" }),
      ])
    default:
      return .unavailable(
        "Guided input controls are not yet supported. Use the project fitting picker.")
    }
  }

  static func runtimeInputs(
    _ inputs: TemplateFitting.Inputs, requirement: Fitting.InputRequirement
  ) -> Fitting.Inputs? {
    switch (inputs, requirement) {
    case (.fixed, .fixed): return .fixed
    case (.downstreamBranches(let count), .downstreamBranches):
      return .downstreamBranches(count: count)
    case (.dimensions(let h, let w), .heightWidth):
      return .heightWidth(heightInches: h, widthInches: w)
    case (.dimensions(let r, let w), .radiusWidth):
      return .radiusWidth(radiusInches: r, widthInches: w)
    case (.sourceTable(let choices), .plenumReturns):
      return .plenumReturns(
        count: choices.first.flatMap { $0 }.flatMap { Int($0.prefix(while: { $0.isNumber })) })
    case (.sourceTable(let choices), .roundElbow):
      let ratio = choices.first.flatMap { $0 }.flatMap {
        Double($0.split(separator: " ").first ?? "")
      }
      .flatMap(Fitting.RoundElbowRadiusRatio.init(rawValue:))
      guard !choices.isEmpty else { return nil }
      let angle =
        choices.count == 1
        ? Fitting.ElbowAngle.degrees90
        : choices[1].flatMap(Int.init).flatMap(Fitting.ElbowAngle.init(rawValue:))
      return .roundElbow(radiusRatio: ratio, angle: angle)
    case (.sourceTable(let choices), .ovalElbow):
      return .ovalElbow(
        pieceCount: choices.first.flatMap { $0 }.flatMap(Int.init).flatMap(
          Fitting.OvalElbowPieceCount.init(rawValue:)))
    case (.sourceTable(let choices), .transition):
      guard choices.count == 2 else { return nil }
      return .transition(
        slope: choices[0].flatMap(Fitting.TransitionSlope.init(rawValue:)),
        areaRatio: choices[1].flatMap(Int.init).flatMap(Fitting.TransitionAreaRatio.init(rawValue:))
      )
    default: return nil
    }
  }

}
