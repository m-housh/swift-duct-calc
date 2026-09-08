import Foundation
import Tagged

/// Identities and explicit inputs shared by the catalog, templates, and saved paths.
public enum Fitting {
  public typealias ID = Tagged<Fitting, String>

  public struct Definition: Codable, Equatable, Identifiable, Sendable {
    public let id: ID
    public let group: Group
    public let sourceCode: String?
    public let name: String
    public let artworkPath: String?
    public let sourcePages: [Int]
    public let notes: [String]
    public let requirements: Requirements

    public init(
      id: ID, group: Group, sourceCode: String?, name: String, artworkPath: String?,
      sourcePages: [Int], notes: [String], requirements: Requirements
    ) {
      self.id = id
      self.group = group
      self.sourceCode = sourceCode
      self.name = name
      self.artworkPath = artworkPath
      self.sourcePages = sourcePages
      self.notes = notes
      self.requirements = requirements
    }
  }

  public enum Requirements: Codable, Equatable, Sendable {
    case fixed
    case dimensions(numerator: String, denominator: String)
    case downstreamBranches
    case sourceTable(axes: [Axis])
    case unavailable(String)

    public var emptyInputs: Inputs? {
      switch self {
      case .fixed: return .fixed
      case .dimensions: return .dimensions(numeratorInches: nil, denominatorInches: nil)
      case .downstreamBranches: return .downstreamBranches(nil)
      case .sourceTable(let axes): return .sourceTable(choices: axes.map { _ in nil })
      case .unavailable: return nil
      }
    }

    public func accepts(_ inputs: Inputs) -> Bool {
      switch (self, inputs) {
      case (.fixed, .fixed), (.dimensions, .dimensions), (.downstreamBranches, .downstreamBranches):
        return true
      case (.sourceTable(let axes), .sourceTable(let choices)):
        return axes.count == choices.count
          && zip(axes, choices).allSatisfy { axis, choice in
            choice.map { axis.options.contains($0) } ?? true
          }
      default: return false
      }
    }
  }

  public struct Axis: Codable, Equatable, Sendable {
    public let label: String
    public let options: [String]
    public init(label: String, options: [String]) {
      self.label = label
      self.options = options
    }
  }

  public struct EvaluationRequest: Codable, Equatable, Sendable {
    public let type: EquivalentLength.EffectiveLengthType
    public let fittingID: ID
    public let inputs: Inputs
    public init(type: EquivalentLength.EffectiveLengthType, fittingID: ID, inputs: Inputs) {
      self.type = type
      self.fittingID = fittingID
      self.inputs = inputs
    }
  }

  public enum Evaluation: Codable, Equatable, Sendable {
    case resolved(Calculation)
    case unresolved(String)
  }

  public struct Calculation: Codable, Equatable, Sendable {
    public let fittingID: ID
    public let inputs: Inputs
    public let equivalentLengthFeet: Double
    public let ruleRevision: String
    public init(fittingID: ID, inputs: Inputs, equivalentLengthFeet: Double, ruleRevision: String) {
      self.fittingID = fittingID
      self.inputs = inputs
      self.equivalentLengthFeet = equivalentLengthFeet
      self.ruleRevision = ruleRevision
    }
  }

  public enum Group: Int, CaseIterable, Codable, Sendable {
    case supplyConnection = 1
    case supplyTakeoff = 2
    case reducingTakeoff = 3
    case supplyBoot = 4
    case returnConnection = 5
    case returnTakeoff = 6
    case returnSpace = 7
    case elbow = 8
    case supplyAccessory = 9
    case returnAccessory = 10
    case flexJunction = 11
    case transition = 12

    public func supports(_ type: EquivalentLength.EffectiveLengthType) -> Bool {
      switch self {
      case .supplyConnection, .supplyTakeoff, .reducingTakeoff, .supplyBoot, .supplyAccessory:
        return type == .supply
      case .returnConnection, .returnTakeoff, .returnSpace, .returnAccessory:
        return type == .return
      case .elbow, .flexJunction, .transition:
        return true
      }
    }
  }

  /// Nil fields mean unanswered. Defaults apply when a draft is created, never on evaluation.
  public enum Inputs: Codable, Equatable, Sendable {
    case fixed
    case dimensions(numeratorInches: Double?, denominatorInches: Double?)
    case downstreamBranches(Int?)
    /// Exact catalog option IDs, in the definition's source-axis order.
    case sourceTable(choices: [String?])
    case flexJunctionBox(FlexJunctionInputs)
  }

  public struct FlexJunctionInputs: Codable, Equatable, Sendable {
    public var boxVelocityFpm: Double?
    public var openings: Openings?
    public var suppliedBend: SuppliedBend?

    public init(
      boxVelocityFpm: Double? = nil,
      openings: Openings? = nil,
      suppliedBend: SuppliedBend? = nil
    ) {
      self.boxVelocityFpm = boxVelocityFpm
      self.openings = openings
      self.suppliedBend = suppliedBend
    }
  }

  public enum Openings: String, Codable, Sendable {
    case sidewall
    case topOrBottom
  }

  public struct SuppliedBend: Codable, Equatable, Sendable {
    public var velocityFpm: Double?
    public var radiusRatioOption: String?

    public init(velocityFpm: Double? = nil, radiusRatioOption: String? = nil) {
      self.velocityFpm = velocityFpm
      self.radiusRatioOption = radiusRatioOption
    }
  }
}
