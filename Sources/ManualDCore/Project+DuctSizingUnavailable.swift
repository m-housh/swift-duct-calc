import Foundation

extension Project {
  public struct DuctSizingUnavailable: LocalizedError, Equatable, Sendable {
    public enum Input: String, CaseIterable, Sendable {
      case equipment = "Add equipment airflow and static pressure."
      case sensibleHeatRatio = "Set the sensible heat ratio in Rooms."
      case rooms = "Add room loads."
      case supplyPath = "Add a supply T.E.L. path."
      case returnPath = "Add a return T.E.L. path."
      case componentLosses = "Add component pressure losses in Friction Rate."
    }

    public let missingInputs: [Input]

    public init(missingInputs: [Input]) {
      self.missingInputs = missingInputs
    }

    public var errorDescription: String? {
      (["Duct sizing needs more information."] + missingInputs.map(\.rawValue))
        .joined(separator: " ")
    }
  }
}
