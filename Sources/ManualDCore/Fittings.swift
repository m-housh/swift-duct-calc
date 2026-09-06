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
  }

  public enum Shape: String, Codable, Sendable {
    case round, rectangular, mixed
  }

  public enum View: String, Codable, Sendable {
    case individual, assembly
  }

  public enum Inputs: Codable, Equatable, Sendable {
    case fixed
    case heightWidth(heightInches: Double?, widthInches: Double?)
    case downstreamBranches(count: Int?)
  }

  /// Presentation requirements derived from the same rule used for evaluation.
  public enum InputRequirement: Equatable, Sendable {
    case fixed
    case heightWidth(exactRatios: [Double])
    case downstreamBranches(finalBucketMinimum: Int)
  }

  public struct Source: Codable, Equatable, Sendable {
    public let pdfPath: String
    public let pdfSHA256: String
    public let pdfPage: Int
    public let printedPage: Int
    public let referenceVelocityFPM: Int
    public let frictionRateIWCPer100Feet: Double
    public let conditions: [String]

    public init(
      pdfPath: String, pdfSHA256: String, pdfPage: Int, printedPage: Int,
      referenceVelocityFPM: Int, frictionRateIWCPer100Feet: Double, conditions: [String]
    ) {
      self.pdfPath = pdfPath
      self.pdfSHA256 = pdfSHA256
      self.pdfPage = pdfPage
      self.printedPage = printedPage
      self.referenceVelocityFPM = referenceVelocityFPM
      self.frictionRateIWCPer100Feet = frictionRateIWCPer100Feet
      self.conditions = conditions
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
    public let inputRequirement: InputRequirement
    /// Initial values for a new draft only. Evaluation never applies defaults.
    public let defaultInputs: Inputs
    public let source: Source

    public init(
      id: ID, groupID: Group.ID, familyID: ID, sourceCode: SourceCode?, name: String,
      shape: Shape, pathTypes: [PathType], inputRequirement: InputRequirement,
      defaultInputs: Inputs, source: Source
    ) {
      self.id = id
      self.groupID = groupID
      self.familyID = familyID
      self.sourceCode = sourceCode
      self.name = name
      self.shape = shape
      self.pathTypes = pathTypes
      self.inputRequirement = inputRequirement
      self.defaultInputs = defaultInputs
      self.source = source
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
    public enum Field: Equatable, Sendable {
      case heightInches, widthInches, downstreamBranches
    }

    public enum Code: Equatable, Sendable {
      case unknownFitting, ineligiblePathType, incompatibleInputs
      case missingInput, nonfiniteInput, nonpositiveDimension, negativeBranchCount
      case unsupportedRatio
    }

    public let code: Code
    public let field: Field?

    public init(_ code: Code, field: Field? = nil) {
      self.code = code
      self.field = field
    }
  }

  public enum Evaluation: Equatable, Sendable {
    case resolved(Calculation)
    case unresolved([Issue])
  }

  public struct Calculation: Codable, Equatable, Sendable {
    public struct Component: Codable, Equatable, Sendable {
      public let ruleKey: String
      public let equivalentLengthFeet: Double

      public init(ruleKey: String, equivalentLengthFeet: Double) {
        self.ruleKey = ruleKey
        self.equivalentLengthFeet = equivalentLengthFeet
      }
    }

    public let fittingID: ID
    public let sourceCode: SourceCode?
    public let equivalentLengthFeet: Double
    /// The submitted dimensions/count remain intact; bucket selection does not overwrite them.
    public let inputs: Inputs
    public let components: [Component]
    public let source: Source
    public let catalogRevision: String
    public let ruleRevision: String

    public init(
      fittingID: ID, sourceCode: SourceCode?, equivalentLengthFeet: Double, inputs: Inputs,
      components: [Component], source: Source, catalogRevision: String, ruleRevision: String
    ) {
      self.fittingID = fittingID
      self.sourceCode = sourceCode
      self.equivalentLengthFeet = equivalentLengthFeet
      self.inputs = inputs
      self.components = components
      self.source = source
      self.catalogRevision = catalogRevision
      self.ruleRevision = ruleRevision
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
