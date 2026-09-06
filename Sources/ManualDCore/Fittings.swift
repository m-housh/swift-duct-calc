import Foundation
import Tagged

/// Shared fitting contracts. Catalog lookup and evaluation live in FittingClient.
public enum Fitting {
  public enum IDTag {}
  public enum SourceCodeTag {}
  public typealias ID = Tagged<IDTag, String>
  public typealias SourceCode = Tagged<SourceCodeTag, String>
  public typealias PathType = EquivalentLength.EffectiveLengthType

  public struct Group: Equatable, Sendable, Identifiable {
    public let id: ID
    public let title: String
    /// Nil when this group has no implemented cases in the current catalog.
    public let representativeFittingID: Fitting.ID?
    public let availableFittingCount: Int

    public init(
      id: ID, title: String, representativeFittingID: Fitting.ID?, availableFittingCount: Int
    ) {
      self.id = id
      self.title = title
      self.representativeFittingID = representativeFittingID
      self.availableFittingCount = availableFittingCount
    }

    public enum ID: Int, Codable, CaseIterable, Sendable {
      case supplyEquipment = 1
      case supplyBranches = 2
      case reducingTrunkTakeoffs = 3
      case supplyBoots = 4
      case returnEquipment = 5
      case returnBranches = 6
      case pannedReturns = 7
      case elbows = 8
      case supplyJunctions = 9
      case returnJunctions = 10
      case flexJunctions = 11
      case transitions = 12
    }
  }

  public enum Shape: String, Codable, Sendable {
    case round, rectangular, mixed
  }

  public enum View: String, Codable, Sendable {
    case individual, assembly
    case assemblyMerging = "assembly-merging"
  }

  /// The selected route through a junction, independent of supply/return path type.
  public enum JunctionPath: String, Codable, CaseIterable, Sendable {
    case branch, main
  }

  /// Published 8A R/D choices. The final choice is an inclusive range, not an exact ratio.
  public enum RoundElbowRadiusRatio: Double, Codable, CaseIterable, Sendable {
    case threeQuarters = 0.75
    case one = 1
    case oneAndHalfOrGreater = 1.5

    public var label: String {
      switch self {
      case .threeQuarters: "0.75"
      case .one: "1.0"
      case .oneAndHalfOrGreater: "1.5 or greater"
      }
    }
  }

  /// Published 8B/8C R/W choices; the final choice includes larger ratios.
  public enum RectangularElbowRadiusRatio: Double, Codable, CaseIterable, Sendable {
    case mitered = 0
    case oneQuarter = 0.25
    case oneHalfOrGreater = 0.5

    public var label: String {
      switch self {
      case .mitered: "Mitered (R/W = 0)"
      case .oneQuarter: "0.25"
      case .oneHalfOrGreater: "0.5 or greater"
      }
    }
  }

  /// Explicit source-table column, selected independently of the radius and angle.
  public enum ElbowBendCategory: String, Codable, CaseIterable, Sendable {
    case hardBend, square, easyBend

    public var label: String {
      switch self {
      case .hardBend: "Hard bend"
      case .square: "Square cross-section (H/W = 1)"
      case .easyBend: "Easy bend"
      }
    }
  }

  /// Published elbow angles; each fitting advertises its supported subset.
  public enum ElbowAngle: Int, Codable, CaseIterable, Sendable {
    case degrees20 = 20
    case degrees30 = 30
    case degrees45 = 45
    case degrees60 = 60
    case degrees75 = 75
    case degrees90 = 90
    case degrees110 = 110
    case degrees130 = 130
    case degrees150 = 150

    public var label: String { "\(rawValue)°" }
  }

  public enum Inputs: Codable, Equatable, Sendable {
    case fixed
    case heightWidth(heightInches: Double?, widthInches: Double?)
    case radiusWidth(radiusInches: Double?, widthInches: Double?)
    case downstreamBranches(count: Int?)
    /// All return ducts entering the plenum, independent of fitting quantity.
    case plenumReturns(count: Int?)
    case junction(path: JunctionPath?)
    /// CFM1 entering the branch and CFM2 in the combined downstream trunk.
    case returnJunction(branchCFM: Double?, totalCFM: Double?)
    case pannedReturn(airflowCFM: Double?, mergingFlow: Bool)
    case roundElbow(radiusRatio: RoundElbowRadiusRatio?, angle: ElbowAngle?)
    case rectangularElbow(
      radiusRatio: RectangularElbowRadiusRatio?, bendCategory: ElbowBendCategory?,
      angle: ElbowAngle?)
  }

  /// Presentation requirements derived from the same rule used for evaluation.
  public enum InputRequirement: Equatable, Sendable {
    case fixed
    case heightWidth(exactRatios: [Double])
    case radiusWidth(exactRatios: [Double])
    case downstreamBranches(finalBucketMinimum: Int)
    case plenumReturns(finalBucketMinimum: Int)
    case junction
    case returnJunction(ratios: [Double], firstRowIncludesLowerRatios: Bool)
    /// Airflow must be within the first and last published rows, before rounding.
    case pannedReturn(airflowRows: [Double], supportsMergingFlow: Bool)
    case roundElbow(radiusRatios: [RoundElbowRadiusRatio], angles: [ElbowAngle])
    case rectangularElbow(
      radiusRatios: [RectangularElbowRadiusRatio], bendCategories: [ElbowBendCategory],
      angles: [ElbowAngle])
  }

  /// Applicability information for the fitting rule, independent of reference-document format.
  public struct Conditions: Codable, Equatable, Sendable {
    public let referenceVelocityFPM: Int
    public let frictionRateIWCPer100Feet: Double
    public let notes: [String]

    public init(
      referenceVelocityFPM: Int, frictionRateIWCPer100Feet: Double, notes: [String]
    ) {
      self.referenceVelocityFPM = referenceVelocityFPM
      self.frictionRateIWCPer100Feet = frictionRateIWCPer100Feet
      self.notes = notes
    }
  }

  public struct Definition: Equatable, Sendable, Identifiable {
    public let id: ID
    public let groupID: Group.ID
    public let familyID: ID
    public let sourceCode: SourceCode?
    public let name: String
    public let shape: Shape
    public let pathTypes: [PathType]
    public let availableViews: [View]
    public let inputRequirement: InputRequirement
    /// Initial values for a new draft only. Evaluation never applies defaults.
    public let defaultInputs: Inputs
    public let conditions: Conditions

    public init(
      id: ID, groupID: Group.ID, familyID: ID, sourceCode: SourceCode?, name: String,
      shape: Shape, pathTypes: [PathType], inputRequirement: InputRequirement,
      defaultInputs: Inputs, conditions: Conditions, availableViews: [View] = [.individual]
    ) {
      self.id = id
      self.groupID = groupID
      self.familyID = familyID
      self.sourceCode = sourceCode
      self.name = name
      self.shape = shape
      self.pathTypes = pathTypes
      self.inputRequirement = inputRequirement
      self.availableViews = availableViews
      self.defaultInputs = defaultInputs
      self.conditions = conditions
    }
  }

  public struct BrowseRequest: Equatable, Sendable {
    public let pathType: PathType
    public let groupID: Group.ID

    public init(pathType: PathType, groupID: Group.ID) {
      self.pathType = pathType
      self.groupID = groupID
    }
  }

  public struct ArtworkRequest: Equatable, Sendable {
    public let fittingID: ID
    public let shape: Shape?
    public let view: View

    public init(fittingID: ID, shape: Shape? = nil, view: View = .individual) {
      self.fittingID = fittingID
      self.shape = shape
      self.view = view
    }
  }

  public struct Artwork: Codable, Equatable, Sendable {
    public let publicPath: String
    public let revision: String
    public let altText: String
    public let view: View
    public let mediaType: String

    public init(
      publicPath: String, revision: String, altText: String, view: View,
      mediaType: String = "image/svg+xml"
    ) {
      self.publicPath = publicPath
      self.revision = revision
      self.altText = altText
      self.view = view
      self.mediaType = mediaType
    }

    public var versionedPath: String { "\(publicPath)?v=\(revision)" }
  }

  public enum ArtworkResolution: Equatable, Sendable {
    case available(Artwork)
    case unavailable(Reason)

    public enum Reason: Equatable, Sendable {
      case unknownFitting, unsupportedShape, unsupportedView
    }
  }

  public struct EvaluationRequest: Equatable, Sendable {
    public let pathType: PathType
    public let fittingID: ID
    public let inputs: Inputs

    public init(pathType: PathType, fittingID: ID, inputs: Inputs) {
      self.pathType = pathType
      self.fittingID = fittingID
      self.inputs = inputs
    }
  }

  public struct Issue: Equatable, Sendable {
    public let code: Code
    public let field: Field?

    public init(_ code: Code, field: Field? = nil) {
      self.code = code
      self.field = field
    }

    public enum Field: Equatable, Sendable {
      case heightInches, widthInches, radiusInches, downstreamBranches, plenumReturns, junctionPath
      case branchCFM, totalCFM, airflowCFM, mergingFlow
      case radiusRatio, elbowAngle, bendCategory
    }

    public enum Code: Equatable, Sendable {
      case unknownFitting, ineligiblePathType, incompatibleInputs
      case missingInput, nonfiniteInput, nonpositiveDimension, negativeBranchCount
      case unsupportedRatio, nonpositiveReturnCount, unsupportedCombination
      case nonpositiveAirflow, branchExceedsTotal, unsupportedAirflow
    }
  }

  public enum Evaluation: Equatable, Sendable {
    case resolved(Calculation)
    /// Both table contributions; the project selects the appropriate one for each path.
    case resolvedReturnJunction(ReturnJunctionCalculation)
    case unresolved([Issue])
  }

  public struct Calculation: Codable, Equatable, Sendable {
    public let fittingID: ID
    public let sourceCode: SourceCode?
    public let equivalentLengthFeet: Double
    /// The submitted dimensions/count remain intact; bucket selection does not overwrite them.
    public let inputs: Inputs
    public let components: [Component]
    public let airflowSelection: AirflowSelection?
    public let conditions: Conditions
    public let catalogRevision: String
    public let ruleRevision: String

    public init(
      fittingID: ID, sourceCode: SourceCode?, equivalentLengthFeet: Double, inputs: Inputs,
      components: [Component], conditions: Conditions, catalogRevision: String,
      ruleRevision: String,
      airflowSelection: AirflowSelection? = nil
    ) {
      self.fittingID = fittingID
      self.sourceCode = sourceCode
      self.equivalentLengthFeet = equivalentLengthFeet
      self.inputs = inputs
      self.components = components
      self.airflowSelection = airflowSelection
      self.conditions = conditions
      self.catalogRevision = catalogRevision
      self.ruleRevision = ruleRevision
    }

    public struct AirflowSelection: Codable, Equatable, Sendable {
      public let submittedCFM: Double
      public let selectedCFM: Double

      public init(submittedCFM: Double, selectedCFM: Double) {
        self.submittedCFM = submittedCFM
        self.selectedCFM = selectedCFM
      }

      public var wasRounded: Bool { submittedCFM != selectedCFM }
    }

    public struct Component: Codable, Equatable, Sendable {
      public let ruleKey: String
      public let equivalentLengthFeet: Double

      public init(ruleKey: String, equivalentLengthFeet: Double) {
        self.ruleKey = ruleKey
        self.equivalentLengthFeet = equivalentLengthFeet
      }
    }
  }

  /// A group 6 table lookup produces two path contributions, not one additive fitting length.
  public struct ReturnJunctionCalculation: Codable, Equatable, Sendable {
    public let fittingID: ID
    public let sourceCode: SourceCode?
    public let inputs: Inputs
    public let branch: Calculation.Component
    /// Nil means the selected source row has no applicable trunk value; it is not zero.
    public let trunk: Calculation.Component?
    public let ratioSelection: RatioSelection
    public let conditions: Conditions
    public let catalogRevision: String
    public let ruleRevision: String

    public init(
      fittingID: ID, sourceCode: SourceCode?, inputs: Inputs,
      branch: Calculation.Component, trunk: Calculation.Component?, ratioSelection: RatioSelection,
      conditions: Conditions, catalogRevision: String, ruleRevision: String
    ) {
      self.fittingID = fittingID
      self.sourceCode = sourceCode
      self.inputs = inputs
      self.branch = branch
      self.trunk = trunk
      self.ratioSelection = ratioSelection
      self.conditions = conditions
      self.catalogRevision = catalogRevision
      self.ruleRevision = ruleRevision
    }

    public struct RatioSelection: Codable, Equatable, Sendable {
      public let calculatedRatio: Double
      public let selectedRatio: Double
      public let reason: Reason

      public init(calculatedRatio: Double, selectedRatio: Double, reason: Reason) {
        self.calculatedRatio = calculatedRatio
        self.selectedRatio = selectedRatio
        self.reason = reason
      }

      public enum Reason: String, Codable, Sendable {
        case exact, rounded, sourceRange
      }
    }
  }

  public struct ReferenceRequest: Equatable, Sendable {
    public let code: String
    public let pathType: PathType

    public init(code: String, pathType: PathType) {
      self.code = code
      self.pathType = pathType
    }
  }

  public struct Reference: Equatable, Sendable {
    public let code: SourceCode
    public let groupID: Group.ID
    /// Candidate catalog cases, not proof of the variant used for a supplied EL.
    public let fittingIDs: [ID]

    public init(code: SourceCode, groupID: Group.ID, fittingIDs: [ID]) {
      self.code = code
      self.groupID = groupID
      self.fittingIDs = fittingIDs
    }
  }

  public enum ReferenceMatch: Equatable, Sendable {
    case recognized(Reference)
    case ineligible(Reference)
    /// Unknown to the currently implemented catalog, not necessarily absent from the PDF.
    case unknown
  }
}
