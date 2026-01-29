import Dependencies
import Foundation

/// Represents the equivalent length of a single duct path.
///
/// These consist of both straight lengths of duct / trunks, as well as the
/// equivalent length of duct fittings.  They are used to determine the worst
/// case total equivalent length of duct that the system fan has to move air
/// through.
///
/// There can be many equivalent lengths saved for a project, however the only
/// ones that matter in most calculations are the longest supply path and the
/// the longest return path.
///
/// It is required that project has at least one equivalent length saved for
/// the supply and one saved for return, otherwise duct sizes can not be calculated.
public struct EquivalentLength: Codable, Equatable, Identifiable, Sendable {

  /// The id of the equivalent length.
  public let id: UUID
  /// The project that this equivalent length is associated with.
  public let projectID: Project.ID
  /// A unique name / label for this equivalent length.
  public let name: String
  /// The type (supply or return) of the equivalent length.
  public let type: EffectiveLengthType
  /// The straight lengths of duct for this equivalent length.
  public let straightLengths: [Int]
  /// The fitting groups associated with this equivalent length.
  public let groups: [FittingGroup]
  /// When this equivalent length was created in the database.
  public let createdAt: Date
  /// When this equivalent length was updated in the database.
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    type: EquivalentLength.EffectiveLengthType,
    straightLengths: [Int],
    groups: [EquivalentLength.FittingGroup],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.name = name
    self.type = type
    self.straightLengths = straightLengths
    self.groups = groups
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension EquivalentLength {

  /// Represents the data needed to create a new ``EquivalentLength`` in the database.
  public struct Create: Codable, Equatable, Sendable {

    /// The project that this equivalent length is associated with.
    public let projectID: Project.ID
    /// A unique name / label for this equivalent length.
    public let name: String
    /// The type (supply or return) of the equivalent length.
    public let type: EffectiveLengthType
    /// The straight lengths of duct for this equivalent length.
    public let straightLengths: [Int]
    /// The fitting groups associated with this equivalent length.
    public let groups: [FittingGroup]

    public init(
      projectID: Project.ID,
      name: String,
      type: EquivalentLength.EffectiveLengthType,
      straightLengths: [Int],
      groups: [EquivalentLength.FittingGroup]
    ) {
      self.projectID = projectID
      self.name = name
      self.type = type
      self.straightLengths = straightLengths
      self.groups = groups
    }
  }

  /// Represents the data needed to update an ``EquivalentLength`` in the database.
  ///
  /// Only the supplied fields are updated.
  public struct Update: Codable, Equatable, Sendable {

    /// A unique name / label for this equivalent length.
    public let name: String?
    /// The type (supply or return) of the equivalent length.
    public let type: EffectiveLengthType?
    /// The straight lengths of duct for this equivalent length.
    public let straightLengths: [Int]?
    /// The fitting groups associated with this equivalent length.
    public let groups: [FittingGroup]?

    public init(
      name: String? = nil,
      type: EquivalentLength.EffectiveLengthType? = nil,
      straightLengths: [Int]? = nil,
      groups: [EquivalentLength.FittingGroup]? = nil
    ) {
      self.name = name
      self.type = type
      self.straightLengths = straightLengths
      self.groups = groups
    }
  }

  /// Represents the type of equivalent length, either supply or return.
  public enum EffectiveLengthType: String, CaseIterable, Codable, Sendable {
    case `return`
    case supply
  }

  /// Represents a Manual-D fitting group.
  ///
  /// These are defined by Manual-D and convert different types of fittings into
  /// an equivalent length of straight duct.
  public struct FittingGroup: Codable, Equatable, Sendable {
    /// The fitting group number.
    public let group: Int
    /// The fitting group letter.
    public let letter: String
    /// The equivalent length of the fitting.
    public let value: Double
    /// The quantity of the fittings in the path.
    public let quantity: Int

    public init(
      group: Int,
      letter: String,
      value: Double,
      quantity: Int = 1
    ) {
      self.group = group
      self.letter = letter
      self.value = value
      self.quantity = quantity
    }
  }

  // TODO: Should these not be optional and we just throw an error or return nil from
  //       a database query.

  /// Represents the max ``EquivalentLength``'s for a project.
  ///
  /// Calculating the duct sizes for a project requires there to be a max supply
  /// and a max return equivalent length, so this container represents those values
  /// when they exist in the database.
  public struct MaxContainer: Codable, Equatable, Sendable {

    /// The longest supply equivalent length.
    public let supply: EquivalentLength?
    /// The longest return equivalent length.
    public let `return`: EquivalentLength?

    public var totalEquivalentLength: Double? {
      guard let supply else { return nil }
      guard let `return` else { return nil }
      return supply.totalEquivalentLength + `return`.totalEquivalentLength
    }

    public init(supply: EquivalentLength? = nil, return: EquivalentLength? = nil) {
      self.supply = supply
      self.return = `return`
    }
  }
}

extension EquivalentLength {

  /// The calculated total equivalent length.
  ///
  /// This is the sum of all the straigth lengths and fitting groups (with quantities).
  public var totalEquivalentLength: Double {
    straightLengths.reduce(into: 0.0) { $0 += Double($1) }
      + groups.totalEquivalentLength
  }
}

extension Array where Element == EquivalentLength.FittingGroup {

  /// The calculated total equivalent length for the fitting groups.
  public var totalEquivalentLength: Double {
    reduce(into: 0.0) {
      $0 += ($1.value * Double($1.quantity))
    }
  }
}

#if DEBUG

  extension EquivalentLength {

    public static func mock(projectID: Project.ID) -> [Self] {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return [
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Supply - 1",
          type: .supply,
          straightLengths: [10, 25],
          groups: [
            .init(group: 1, letter: "a", value: 20),
            .init(group: 2, letter: "b", value: 30, quantity: 1),
            .init(group: 3, letter: "a", value: 10, quantity: 1),
            .init(group: 12, letter: "a", value: 10, quantity: 1),
          ],
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Return - 1",
          type: .return,
          straightLengths: [10, 20, 5],
          groups: [
            .init(group: 5, letter: "a", value: 10),
            .init(group: 6, letter: "a", value: 15, quantity: 1),
            .init(group: 7, letter: "a", value: 20, quantity: 1),
          ],
          createdAt: now,
          updatedAt: now
        ),
      ]
    }
  }

#endif
